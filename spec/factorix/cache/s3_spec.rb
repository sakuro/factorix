# frozen_string_literal: true

require "fileutils"
require "pathname"
require "securerandom"
require "tmpdir"

RSpec.describe Factorix::Cache::S3 do
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:bucket) { "test-bucket" }
  let(:cache_type) { "download" }
  let(:cache) { Factorix::Cache::S3.new(bucket:, cache_type:) }
  let(:logical_key) { "test-key" }
  let(:storage_key) { "cache/#{cache_type}/#{logical_key}" }
  let(:lock_key) { "cache/#{cache_type}/#{logical_key}.lock" }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
  end

  describe "#initialize" do
    it "creates S3 client with provided region" do
      Factorix::Cache::S3.new(bucket:, cache_type:, region: "us-west-2")
      expect(Aws::S3::Client).to have_received(:new).with(region: "us-west-2")
    end

    it "creates S3 client without region when not provided (uses SDK default)" do
      Factorix::Cache::S3.new(bucket:, cache_type:)
      expect(Aws::S3::Client).to have_received(:new).with(no_args)
    end

    it "accepts ttl parameter" do
      cache_with_ttl = Factorix::Cache::S3.new(bucket:, cache_type:, ttl: 3600)
      expect(cache_with_ttl.ttl).to eq(3600)
    end

    it "accepts lock_timeout parameter" do
      expect { Factorix::Cache::S3.new(bucket:, cache_type:, lock_timeout: 60) }.not_to raise_error
    end

    it "inherits from Base" do
      expect(Factorix::Cache::S3.superclass).to eq(Factorix::Cache::Base)
    end
  end

  describe "#exist?" do
    context "when object exists and is not expired" do
      before do
        s3_client.stub_responses(:head_object, {
          content_length: 100,
          last_modified: Time.now,
          metadata: {}
        })
      end

      it "returns true" do
        expect(cache.exist?(logical_key)).to be true
      end
    end

    context "when object does not exist" do
      before do
        s3_client.stub_responses(:head_object, "NotFound")
      end

      it "returns false" do
        expect(cache.exist?(logical_key)).to be false
      end
    end

    context "when object exists but is expired" do
      let(:cache) { Factorix::Cache::S3.new(bucket:, cache_type:, ttl: 3600) }

      before do
        s3_client.stub_responses(:head_object, {
          content_length: 100,
          last_modified: Time.now - 7200,
          metadata: {"expires-at" => (Time.now.to_i - 3600).to_s}
        })
      end

      it "returns false" do
        expect(cache.exist?(logical_key)).to be false
      end
    end
  end

  describe "#read" do
    context "when cache entry exists and is not expired" do
      before do
        s3_client.stub_responses(:head_object, {content_length: 100, metadata: {}})
        s3_client.stub_responses(:get_object, {body: StringIO.new("cached content"), metadata: {}})
      end

      it "reads data from S3" do
        expect(cache.read(logical_key)).to eq("cached content")
      end
    end

    context "when cache entry does not exist" do
      before do
        s3_client.stub_responses(:head_object, "NotFound")
        s3_client.stub_responses(:get_object, "NotFound")
      end

      it "returns nil" do
        expect(cache.read(logical_key)).to be_nil
      end
    end

    context "when cache entry is expired" do
      let(:cache) { Factorix::Cache::S3.new(bucket:, cache_type:, ttl: 3600) }

      before do
        s3_client.stub_responses(:head_object, {
          content_length: 100,
          metadata: {"expires-at" => (Time.now.to_i - 100).to_s}
        })
      end

      it "returns nil" do
        expect(cache.read(logical_key)).to be_nil
      end
    end
  end

  describe "#write_to" do
    let(:output_file) { Pathname(Dir.mktmpdir("output")) / "file.dat" }

    after { FileUtils.remove_entry(output_file.dirname) }

    context "when cache entry exists and is not expired" do
      before do
        s3_client.stub_responses(:head_object, {content_length: 100, metadata: {}})
        s3_client.stub_responses(:get_object, {body: StringIO.new("cached content"), metadata: {}})
      end

      it "writes cached content to output file" do
        expect(cache.write_to(logical_key, output_file)).to be true
        expect(output_file.read).to eq("cached content")
      end
    end

    context "when cache entry does not exist" do
      before do
        s3_client.stub_responses(:head_object, "NotFound")
        s3_client.stub_responses(:get_object, "NotFound")
      end

      it "returns false" do
        expect(cache.write_to(logical_key, output_file)).to be false
      end
    end
  end

  describe "#store" do
    let(:source_file) { Pathname(Dir.mktmpdir("source")) / "file.zip" }

    before do
      source_file.binwrite("test content")
      s3_client.stub_responses(:put_object, {})
    end

    after { FileUtils.remove_entry(source_file.dirname) }

    it "uploads data to S3" do
      expect(cache.store(logical_key, source_file)).to be true
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::S3.new(bucket:, cache_type:, ttl: 3600) }

      it "stores data successfully" do
        expect(cache.store(logical_key, source_file)).to be true
      end
    end
  end

  describe "#delete" do
    context "when object exists" do
      before do
        s3_client.stub_responses(:head_object, {content_length: 100, metadata: {}})
        s3_client.stub_responses(:delete_object, {})
      end

      it "deletes the object and returns true" do
        expect(cache.delete(logical_key)).to be true
      end
    end

    context "when object does not exist" do
      before do
        s3_client.stub_responses(:head_object, "NotFound")
      end

      it "returns false" do
        expect(cache.delete(logical_key)).to be false
      end
    end
  end

  describe "#clear" do
    before do
      s3_client.stub_responses(:list_objects_v2, {
        contents: [
          {key: "cache/download/key1", size: 100, last_modified: Time.now},
          {key: "cache/download/key2", size: 200, last_modified: Time.now},
          {key: "cache/download/key3.lock", size: 50, last_modified: Time.now}
        ],
        is_truncated: false
      })
      s3_client.stub_responses(:delete_objects, {deleted: []})
    end

    it "deletes all objects except lock files" do
      expect { cache.clear }.not_to raise_error
    end
  end

  describe "#age" do
    context "when object exists" do
      before do
        s3_client.stub_responses(:head_object, {
          content_length: 100,
          last_modified: Time.now - 3600,
          metadata: {}
        })
      end

      it "returns age in seconds based on last_modified" do
        expect(cache.age(logical_key)).to be_within(1).of(3600)
      end
    end

    context "when object does not exist" do
      before do
        s3_client.stub_responses(:head_object, "NotFound")
      end

      it "returns nil" do
        expect(cache.age(logical_key)).to be_nil
      end
    end
  end

  describe "#expired?" do
    context "when TTL is nil" do
      it "returns false" do
        s3_client.stub_responses(:head_object, {content_length: 100, metadata: {}})
        expect(cache.expired?(logical_key)).to be false
      end
    end

    context "when TTL is set" do
      let(:cache) { Factorix::Cache::S3.new(bucket:, cache_type:, ttl: 3600) }

      context "when object is not expired" do
        before do
          s3_client.stub_responses(:head_object, {
            content_length: 100,
            metadata: {"expires-at" => (Time.now.to_i + 1800).to_s}
          })
        end

        it "returns false" do
          expect(cache.expired?(logical_key)).to be false
        end
      end

      context "when object is expired" do
        before do
          s3_client.stub_responses(:head_object, {
            content_length: 100,
            metadata: {"expires-at" => (Time.now.to_i - 100).to_s}
          })
        end

        it "returns true" do
          expect(cache.expired?(logical_key)).to be true
        end
      end

      context "when object does not exist" do
        before do
          s3_client.stub_responses(:head_object, "NotFound")
        end

        it "returns true" do
          expect(cache.expired?(logical_key)).to be true
        end
      end
    end
  end

  describe "#size" do
    context "when object exists and is not expired" do
      before do
        s3_client.stub_responses(:head_object, {content_length: 1024, metadata: {}})
      end

      it "returns size in bytes" do
        expect(cache.size(logical_key)).to eq(1024)
      end
    end

    context "when object does not exist" do
      before do
        s3_client.stub_responses(:head_object, "NotFound")
      end

      it "returns nil" do
        expect(cache.size(logical_key)).to be_nil
      end
    end
  end

  describe "#with_lock" do
    context "when lock is acquired successfully" do
      before do
        s3_client.stub_responses(:put_object, {})
        s3_client.stub_responses(:delete_object, {})
      end

      it "executes block and releases lock" do
        executed = false
        cache.with_lock(logical_key) { executed = true }
        expect(executed).to be true
      end

      it "returns block result" do
        result = cache.with_lock(logical_key) { "result" }
        expect(result).to eq("result")
      end
    end

    context "when lock acquisition fails due to timeout" do
      let(:cache) { Factorix::Cache::S3.new(bucket:, cache_type:, lock_timeout: 0.2) }

      before do
        s3_client.stub_responses(:put_object, "PreconditionFailed")
        s3_client.stub_responses(:get_object, {
          body: StringIO.new("uuid:#{Time.now.to_i + 3600}")
        })
      end

      it "raises LockTimeoutError" do
        expect { cache.with_lock(logical_key) { "never executed" } }.to raise_error(Factorix::LockTimeoutError)
      end
    end

    context "when lock is stale and gets cleaned up" do
      before do
        call_count = 0
        s3_client.stub_responses(:put_object, ->(_context) {
          call_count += 1
          if call_count == 1
            "PreconditionFailed"
          else
            {}
          end
        })
        s3_client.stub_responses(:get_object, {
          body: StringIO.new("uuid:#{Time.now.to_i - 100}")
        })
        s3_client.stub_responses(:delete_object, {})
      end

      it "cleans up stale lock and acquires new lock" do
        executed = false
        cache.with_lock(logical_key) { executed = true }
        expect(executed).to be true
      end
    end
  end

  describe "#each" do
    before do
      s3_client.stub_responses(:list_objects_v2, {
        contents: [
          {key: "cache/download/key1", size: 100, last_modified: Time.now - 3600},
          {key: "cache/download/key2", size: 200, last_modified: Time.now - 1800},
          {key: "cache/download/key3.lock", size: 50, last_modified: Time.now}
        ],
        is_truncated: false
      })
      s3_client.stub_responses(:head_object, {content_length: 100, metadata: {}})
    end

    it "returns an enumerator when no block given" do
      expect(cache.each).to be_a(Enumerator)
    end

    it "yields key-entry pairs excluding lock files" do
      entries = cache.each.to_a
      expect(entries.size).to eq(2)
      expect(entries.map(&:first)).to contain_exactly("key1", "key2")
    end

    it "yields Entry objects with correct attributes" do
      entries = cache.each.to_a
      entry = entries.find {|k, _| k == "key1" }&.last
      expect(entry).to be_a(Factorix::Cache::Entry)
      expect(entry.size).to eq(100)
      expect(entry.age).to be_within(10).of(3600)
    end
  end

  describe "#each with pagination" do
    before do
      s3_client.stub_responses(:list_objects_v2, [
        {
          contents: [{key: "cache/download/key1", size: 100, last_modified: Time.now}],
          is_truncated: true,
          next_continuation_token: "token1"
        },
        {
          contents: [{key: "cache/download/key2", size: 200, last_modified: Time.now}],
          is_truncated: false
        }
      ])
      s3_client.stub_responses(:head_object, {content_length: 100, metadata: {}})
    end

    it "handles pagination correctly" do
      entries = cache.each.to_a
      expect(entries.size).to eq(2)
    end
  end

  describe "#backend_info" do
    it "returns type as s3" do
      expect(cache.backend_info[:type]).to eq("s3")
    end

    it "returns bucket name" do
      expect(cache.backend_info[:bucket]).to eq(bucket)
    end

    it "returns prefix" do
      expect(cache.backend_info[:prefix]).to eq("cache/download/")
    end

    it "returns default lock_timeout" do
      expect(cache.backend_info[:lock_timeout]).to eq(Factorix::Cache::S3::DEFAULT_LOCK_TIMEOUT)
    end

    context "with custom lock_timeout" do
      let(:cache) { Factorix::Cache::S3.new(bucket:, cache_type:, lock_timeout: 60) }

      it "returns configured lock_timeout" do
        expect(cache.backend_info[:lock_timeout]).to eq(60)
      end
    end
  end
end
