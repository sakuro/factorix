# frozen_string_literal: true

require "fileutils"
require "pathname"
require "securerandom"
require "tmpdir"

RSpec.describe Factorix::Cache::Redis do
  let(:redis_client) { instance_double(Redis) }
  let(:cache) { Factorix::Cache::Redis.new(cache_type: "api") }
  let(:logical_key) { "test-key" }
  let(:data_key) { "factorix-cache:api:#{logical_key}" }
  let(:meta_key) { "factorix-cache:api:meta:#{logical_key}" }
  let(:lock_key) { "factorix-cache:api:lock:#{logical_key}" }

  before do
    allow(Redis).to receive(:new).and_return(redis_client)
  end

  describe "#initialize" do
    it "creates Redis client with provided URL" do
      Factorix::Cache::Redis.new(url: "redis://custom:6379/1", cache_type: "api")
      expect(Redis).to have_received(:new).with(url: "redis://custom:6379/1")
    end

    it "creates Redis client with REDIS_URL env when url is nil" do
      allow(ENV).to receive(:fetch).with("REDIS_URL", nil).and_return("redis://env:6379/2")
      Factorix::Cache::Redis.new(cache_type: "api")
      expect(Redis).to have_received(:new).with(url: "redis://env:6379/2")
    end

    it "accepts ttl parameter" do
      cache_with_ttl = Factorix::Cache::Redis.new(cache_type: "api", ttl: 3600)
      expect(cache_with_ttl.ttl).to eq(3600)
    end

    it "accepts lock_timeout parameter" do
      expect { Factorix::Cache::Redis.new(cache_type: "api", lock_timeout: 60) }.not_to raise_error
    end

    it "inherits from Base" do
      expect(Factorix::Cache::Redis.superclass).to eq(Factorix::Cache::Base)
    end
  end

  describe "#exist?" do
    it "checks key existence with namespaced key" do
      allow(redis_client).to receive(:exists?).with(data_key).and_return(true)
      expect(cache.exist?(logical_key)).to be true
    end

    it "returns false when key does not exist" do
      allow(redis_client).to receive(:exists?).with(data_key).and_return(false)
      expect(cache.exist?(logical_key)).to be false
    end
  end

  describe "#read" do
    context "when cache entry exists" do
      it "reads data with binary encoding by default" do
        allow(redis_client).to receive(:get).with(data_key).and_return("cached content")
        content = cache.read(logical_key)
        expect(content).to eq("cached content")
        expect(content.encoding).to eq(Encoding::ASCII_8BIT)
      end

      it "reads data with specified encoding" do
        allow(redis_client).to receive(:get).with(data_key).and_return("UTF-8 content")
        content = cache.read(logical_key, encoding: Encoding::UTF_8)
        expect(content).to eq("UTF-8 content")
        expect(content.encoding).to eq(Encoding::UTF_8)
      end
    end

    context "when cache entry does not exist" do
      it "returns nil" do
        allow(redis_client).to receive(:get).with(data_key).and_return(nil)
        expect(cache.read(logical_key)).to be_nil
      end
    end
  end

  describe "#write_to" do
    let(:output_file) { Pathname(Dir.mktmpdir("output")) / "file.dat" }

    after { FileUtils.remove_entry(output_file.dirname) }

    context "when cache entry exists" do
      it "writes cached content to output file" do
        allow(redis_client).to receive(:get).with(data_key).and_return("cached content")
        expect(cache.write_to(logical_key, output_file)).to be true
        expect(output_file.read).to eq("cached content")
      end
    end

    context "when cache entry does not exist" do
      it "returns false" do
        allow(redis_client).to receive(:get).with(data_key).and_return(nil)
        expect(cache.write_to(logical_key, output_file)).to be false
        expect(output_file).not_to exist
      end
    end
  end

  describe "#store" do
    let(:source_file) { Pathname(Dir.mktmpdir("source")) / "data.bin" }

    before { File.write(source_file, "test content") }
    after { FileUtils.remove_entry(source_file.dirname) }

    it "stores data with auto-generated namespace" do
      allow(redis_client).to receive(:multi).and_yield(redis_client)
      allow(redis_client).to receive(:set)
      allow(redis_client).to receive(:hset)

      expect(cache.store(logical_key, source_file)).to be true
      expect(redis_client).to have_received(:set).with(data_key, "test content")
      expect(redis_client).to have_received(:hset).with(meta_key, "size", 12, "created_at", kind_of(Integer))
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::Redis.new(cache_type: "api", ttl: 3600) }

      it "sets expiry on data and meta keys" do
        allow(redis_client).to receive(:multi).and_yield(redis_client)
        allow(redis_client).to receive(:set)
        allow(redis_client).to receive(:hset)
        allow(redis_client).to receive(:expire)

        cache.store(logical_key, source_file)
        expect(redis_client).to have_received(:expire).with(data_key, 3600)
        expect(redis_client).to have_received(:expire).with(meta_key, 3600)
      end
    end
  end

  describe "#delete" do
    it "deletes both data and meta keys" do
      allow(redis_client).to receive(:del).with(data_key, meta_key).and_return(2)
      expect(cache.delete(logical_key)).to be true
    end

    it "returns false when keys do not exist" do
      allow(redis_client).to receive(:del).with(data_key, meta_key).and_return(0)
      expect(cache.delete(logical_key)).to be false
    end
  end

  describe "#clear" do
    it "scans and deletes all keys in namespace" do
      allow(redis_client).to receive(:scan).with("0", match: "factorix-cache:api:*", count: 100)
        .and_return(["0", %w[factorix-cache:api:key1 factorix-cache:api:key2]])
      allow(redis_client).to receive(:del)

      cache.clear
      expect(redis_client).to have_received(:del).with("factorix-cache:api:key1", "factorix-cache:api:key2")
    end

    it "handles pagination with cursor" do
      allow(redis_client).to receive(:scan).with("0", match: "factorix-cache:api:*", count: 100)
        .and_return(["123", %w[factorix-cache:api:key1]])
      allow(redis_client).to receive(:scan).with("123", match: "factorix-cache:api:*", count: 100)
        .and_return(["0", %w[factorix-cache:api:key2]])
      allow(redis_client).to receive(:del)

      cache.clear
      expect(redis_client).to have_received(:del).with("factorix-cache:api:key1")
      expect(redis_client).to have_received(:del).with("factorix-cache:api:key2")
    end
  end

  describe "#age" do
    it "calculates age from created_at metadata" do
      created_at = (Time.now.to_i - 100).to_s
      allow(redis_client).to receive(:hget).with(meta_key, "created_at").and_return(created_at)
      expect(cache.age(logical_key)).to be_within(1).of(100)
    end

    it "returns nil when entry does not exist" do
      allow(redis_client).to receive(:hget).with(meta_key, "created_at").and_return(nil)
      expect(cache.age(logical_key)).to be_nil
    end

    it "returns nil when created_at is zero" do
      allow(redis_client).to receive(:hget).with(meta_key, "created_at").and_return("0")
      expect(cache.age(logical_key)).to be_nil
    end
  end

  describe "#expired?" do
    it "returns false when key exists" do
      allow(redis_client).to receive(:exists?).with(data_key).and_return(true)
      expect(cache.expired?(logical_key)).to be false
    end

    it "returns true when key does not exist" do
      allow(redis_client).to receive(:exists?).with(data_key).and_return(false)
      expect(cache.expired?(logical_key)).to be true
    end
  end

  describe "#size" do
    it "returns size from metadata" do
      allow(redis_client).to receive(:exists?).with(data_key).and_return(true)
      allow(redis_client).to receive(:hget).with(meta_key, "size").and_return("1024")
      expect(cache.size(logical_key)).to eq(1024)
    end

    it "returns nil when entry does not exist" do
      allow(redis_client).to receive(:exists?).with(data_key).and_return(false)
      expect(cache.size(logical_key)).to be_nil
    end
  end

  describe "#with_lock" do
    it "acquires and releases lock around block" do
      allow(SecureRandom).to receive(:uuid).and_return("test-uuid")
      allow(redis_client).to receive(:set).with(lock_key, "test-uuid", nx: true, ex: 30).and_return(true)
      allow(redis_client).to receive(:eval)

      yielded = false
      cache.with_lock(logical_key) { yielded = true }
      expect(yielded).to be true
      expect(redis_client).to have_received(:eval).with(anything, keys: [lock_key], argv: ["test-uuid"])
    end

    it "retries lock acquisition until success" do
      allow(SecureRandom).to receive(:uuid).and_return("test-uuid")
      call_count = 0
      allow(redis_client).to receive(:set).with(lock_key, "test-uuid", nx: true, ex: 30) do
        call_count += 1
        call_count >= 3
      end
      allow(redis_client).to receive(:eval)
      allow(cache).to receive(:sleep)

      cache.with_lock(logical_key) { nil }
      expect(call_count).to eq(3)
    end

    it "raises LockTimeoutError when lock cannot be acquired" do
      cache_with_short_timeout = Factorix::Cache::Redis.new(cache_type: "api", lock_timeout: 0.2)
      allow(SecureRandom).to receive(:uuid).and_return("test-uuid")
      allow(redis_client).to receive(:set).with(anything, anything, nx: true, ex: 30).and_return(false)
      allow(cache_with_short_timeout).to receive(:sleep)

      expect {
        cache_with_short_timeout.with_lock(logical_key) { nil }
      }.to raise_error(Factorix::LockTimeoutError, /Failed to acquire lock/)
    end
  end

  describe "#each" do
    it "yields key-entry pairs for data keys only" do
      allow(redis_client).to receive(:scan).with("0", match: "factorix-cache:api:*", count: 100).and_return(["0", [
        "factorix-cache:api:key1",
        "factorix-cache:api:meta:key1",
        "factorix-cache:api:lock:key1",
        "factorix-cache:api:key2"
      ]])
      allow(redis_client).to receive(:hgetall).with("factorix-cache:api:meta:key1")
        .and_return({"size" => "100", "created_at" => Time.now.to_i.to_s})
      allow(redis_client).to receive(:hgetall).with("factorix-cache:api:meta:key2")
        .and_return({"size" => "200", "created_at" => Time.now.to_i.to_s})

      keys = cache.each.map {|key, _entry| key }
      expect(keys).to eq(%w[key1 key2])
    end

    it "returns enumerator when no block given" do
      allow(redis_client).to receive(:scan).and_return(["0", []])
      expect(cache.each).to be_a(Enumerator)
    end

    it "yields Entry objects with correct attributes" do
      created_at = Time.now.to_i - 50
      allow(redis_client).to receive(:scan).with("0", match: "factorix-cache:api:*", count: 100)
        .and_return(["0", ["factorix-cache:api:key1"]])
      allow(redis_client).to receive(:hgetall).with("factorix-cache:api:meta:key1")
        .and_return({"size" => "100", "created_at" => created_at.to_s})

      entries = cache.each.map {|_key, entry| entry }

      expect(entries.size).to eq(1)
      expect(entries.first.size).to eq(100)
      expect(entries.first.age).to be_within(1).of(50)
      expect(entries.first.expired?).to be false
    end
  end
end
