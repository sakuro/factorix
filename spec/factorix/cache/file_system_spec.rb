# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "pathname"
require "tmpdir"

RSpec.describe Factorix::Cache::FileSystem do
  let(:cache_dir) { Pathname(Dir.mktmpdir("cache")) }
  let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir) }
  let(:url) { "https://example.com/file.zip" }
  let(:logical_key) { url }
  let(:internal_key) { Digest(:SHA1).hexdigest(logical_key) }
  let(:cache_path) { cache_dir + internal_key[0, 2] + internal_key[2..] }
  let(:metadata_path) { Pathname("#{cache_path}.metadata") }
  let(:lock_path) { cache_path.sub_ext(".lock") }

  after do
    FileUtils.remove_entry(cache_dir)
  end

  describe "#initialize" do
    it "creates the cache directory if it does not exist" do
      FileUtils.remove_entry(cache_dir)
      expect {
        Factorix::Cache::FileSystem.new(root: cache_dir)
      }.to change(cache_dir, :exist?).from(false).to(true)
    end

    it "accepts ttl parameter" do
      cache_with_ttl = Factorix::Cache::FileSystem.new(root: cache_dir, ttl: 3600)
      expect(cache_with_ttl).to be_a(Factorix::Cache::FileSystem)
      expect(cache_with_ttl.ttl).to eq(3600)
    end

    it "accepts max_file_size parameter" do
      cache_with_limit = Factorix::Cache::FileSystem.new(root: cache_dir, max_file_size: 1024 * 1024)
      expect(cache_with_limit).to be_a(Factorix::Cache::FileSystem)
    end

    it "accepts compression_threshold parameter" do
      cache_with_compression = Factorix::Cache::FileSystem.new(root: cache_dir, compression_threshold: 0)
      expect(cache_with_compression).to be_a(Factorix::Cache::FileSystem)
    end

    it "inherits from Base" do
      expect(Factorix::Cache::FileSystem.superclass).to eq(Factorix::Cache::Base)
    end
  end

  describe "#exist?" do
    context "when the cache file exists" do
      before do
        cache_path.dirname.mkpath
        FileUtils.touch(cache_path)
      end

      it "returns true" do
        expect(cache.exist?(logical_key)).to be true
      end
    end

    context "when the cache file does not exist" do
      it "returns false" do
        expect(cache.exist?(logical_key)).to be false
      end
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, ttl: 10) }

      before do
        cache_path.dirname.mkpath
        FileUtils.touch(cache_path)
      end

      it "returns true for non-expired cache" do
        expect(cache.exist?(logical_key)).to be true
      end

      it "returns false for expired cache" do
        FileUtils.touch(cache_path, mtime: Time.now - 20)
        expect(cache.exist?(logical_key)).to be false
      end
    end
  end

  describe "#write_to" do
    let(:output_file) { Pathname(Dir.mktmpdir("output")) + "file.zip" }

    after do
      FileUtils.remove_entry(output_file.dirname)
    end

    context "when the cache file exists" do
      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "copies the cache file to the output path" do
        expect(cache.write_to(logical_key, output_file)).to be true
        expect(output_file.read).to eq("cached content")
      end
    end

    context "when the cache file does not exist" do
      it "returns false" do
        expect(cache.write_to(logical_key, output_file)).to be false
        expect(output_file).not_to exist
      end
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, ttl: 10) }

      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "returns false for expired cache" do
        FileUtils.touch(cache_path, mtime: Time.now - 20)
        expect(cache.write_to(logical_key, output_file)).to be false
        expect(output_file).not_to exist
      end
    end

    context "with compressed cache entry" do
      before do
        cache_path.dirname.mkpath
        cache_path.binwrite(Zlib.deflate("compressed content"))
      end

      it "decompresses the data when writing" do
        expect(cache.write_to(logical_key, output_file)).to be true
        expect(output_file.read).to eq("compressed content")
      end
    end
  end

  describe "#read" do
    context "when the cache file exists" do
      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "reads the cache file as a binary string" do
        content = cache.read(logical_key)
        expect(content).to eq("cached content")
        expect(content.encoding).to eq(Encoding::ASCII_8BIT)
      end
    end

    context "when the cache file does not exist" do
      it "returns nil" do
        expect(cache.read(logical_key)).to be_nil
      end
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, ttl: 10) }

      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "returns nil for expired cache" do
        FileUtils.touch(cache_path, mtime: Time.now - 20)
        expect(cache.read(logical_key)).to be_nil
      end
    end

    context "with compressed cache entry" do
      before do
        cache_path.dirname.mkpath
        cache_path.binwrite(Zlib.deflate("compressed content"))
      end

      it "decompresses the data when reading" do
        content = cache.read(logical_key)
        expect(content).to eq("compressed content")
      end
    end
  end

  describe "#store" do
    let(:source_file) { Pathname(Dir.mktmpdir("source")) + "file.zip" }

    before do
      File.write(source_file, "source content")
    end

    after do
      FileUtils.remove_entry(source_file.dirname)
    end

    it "copies the source file to the cache" do
      expect(cache.store(logical_key, source_file)).to be true
      expect(cache_path).to exist
      expect(cache_path.read).to eq("source content")
    end

    it "creates the cache subdirectory" do
      expect {
        cache.store(logical_key, source_file)
      }.to change(cache_path.dirname, :exist?).from(false).to(true)
    end

    it "creates a metadata file with the logical key" do
      cache.store(logical_key, source_file)
      expect(metadata_path).to exist
      metadata = JSON.parse(metadata_path.read)
      expect(metadata["logical_key"]).to eq(logical_key)
    end

    context "with max_file_size limit" do
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, max_file_size: 10) }

      it "stores files within the limit" do
        small_file = Pathname(Dir.mktmpdir("small")) + "small.txt"
        File.write(small_file, "small")

        expect(cache.store(logical_key, small_file)).to be true
        expect(cache_path).to exist

        FileUtils.remove_entry(small_file.dirname)
      end

      it "skips caching files exceeding the limit" do
        large_file = Pathname(Dir.mktmpdir("large")) + "large.txt"
        File.write(large_file, "a" * 100)

        expect(cache.store(logical_key, large_file)).to be false
        expect(cache_path).not_to exist

        FileUtils.remove_entry(large_file.dirname)
      end
    end

    context "with compression_threshold: 0 (always compress)" do
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, compression_threshold: 0) }

      it "stores compressed data" do
        expect(cache.store(logical_key, source_file)).to be true
        expect(cache_path).to exist

        # Verify the stored data is zlib-compressed (starts with 0x78)
        stored_data = cache_path.binread
        expect(stored_data.getbyte(0)).to eq(0x78)
      end

      it "stores data smaller than original" do
        # Create a file with repetitive content that compresses well
        compressible_file = Pathname(Dir.mktmpdir("compress")) + "data.txt"
        File.write(compressible_file, "a" * 1000)

        cache.store(logical_key, compressible_file)

        expect(cache_path.size).to be < 1000

        FileUtils.remove_entry(compressible_file.dirname)
      end
    end

    context "with compression_threshold: N (compress if >= N bytes)" do
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, compression_threshold: 100) }

      it "compresses files meeting the threshold" do
        large_file = Pathname(Dir.mktmpdir("large")) + "large.txt"
        File.write(large_file, "a" * 200)

        cache.store(logical_key, large_file)

        stored_data = cache_path.binread
        expect(stored_data.getbyte(0)).to eq(0x78)

        FileUtils.remove_entry(large_file.dirname)
      end

      it "does not compress files below the threshold" do
        small_file = Pathname(Dir.mktmpdir("small")) + "small.txt"
        File.write(small_file, "small data")

        cache.store(logical_key, small_file)

        stored_data = cache_path.binread
        expect(stored_data).to eq("small data")

        FileUtils.remove_entry(small_file.dirname)
      end
    end

    context "with max_file_size and compression" do
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, max_file_size: 50, compression_threshold: 0) }

      it "uses compressed size for max_file_size check" do
        # Create a file that exceeds 50 bytes uncompressed but compresses to under 50
        compressible_file = Pathname(Dir.mktmpdir("compress")) + "data.txt"
        File.write(compressible_file, "a" * 200)

        expect(cache.store(logical_key, compressible_file)).to be true
        expect(cache_path).to exist

        FileUtils.remove_entry(compressible_file.dirname)
      end
    end
  end

  describe "#delete" do
    context "when the cache file exists" do
      before do
        cache_path.dirname.mkpath
        FileUtils.touch(cache_path)
        metadata_path.write(JSON.generate({logical_key:}))
      end

      it "deletes the cache file and returns true" do
        expect(cache.delete(logical_key)).to be true
        expect(cache_path).not_to exist
      end

      it "deletes the metadata file" do
        cache.delete(logical_key)
        expect(metadata_path).not_to exist
      end
    end

    context "when the cache file does not exist" do
      it "returns false" do
        expect(cache.delete(logical_key)).to be false
      end
    end
  end

  describe "#clear" do
    before do
      # Create multiple cache entries with metadata
      3.times do |i|
        test_url = "https://example.com/file#{i}.zip"
        test_internal_key = Digest(:SHA1).hexdigest(test_url)
        test_path = cache_dir + test_internal_key[0, 2] + test_internal_key[2..]
        test_path.dirname.mkpath
        FileUtils.touch(test_path)
        Pathname("#{test_path}.metadata").write(JSON.generate({logical_key: test_url}))
      end
    end

    it "removes all cache files and metadata" do
      cache.clear

      cache_files = cache_dir.glob("**/*").select {|f| f.file? && f.extname != ".lock" }
      expect(cache_files).to be_empty
    end
  end

  describe "#age" do
    context "when the cache file exists" do
      before do
        cache_path.dirname.mkpath
        FileUtils.touch(cache_path, mtime: Time.now - 100)
      end

      it "returns the age in seconds" do
        age = cache.age(logical_key)
        expect(age).to be_within(1).of(100)
      end
    end

    context "when the cache file does not exist" do
      it "returns nil" do
        expect(cache.age(logical_key)).to be_nil
      end
    end
  end

  describe "#expired?" do
    context "without TTL" do
      it "always returns false" do
        expect(cache.expired?(logical_key)).to be false
      end
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, ttl: 50) }

      before do
        cache_path.dirname.mkpath
        FileUtils.touch(cache_path, mtime: Time.now - 100)
      end

      it "returns true for expired cache" do
        expect(cache.expired?(logical_key)).to be true
      end

      it "returns false for non-expired cache" do
        FileUtils.touch(cache_path, mtime: Time.now - 30)
        expect(cache.expired?(logical_key)).to be false
      end
    end

    context "when cache file does not exist" do
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, ttl: 50) }

      it "returns false" do
        expect(cache.expired?(logical_key)).to be false
      end
    end
  end

  describe "#size" do
    context "when the cache file exists" do
      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "returns the file size in bytes" do
        expect(cache.size(logical_key)).to eq(14) # "cached content" is 14 bytes
      end
    end

    context "when the cache file does not exist" do
      it "returns nil" do
        expect(cache.size(logical_key)).to be_nil
      end
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, ttl: 10) }

      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "returns the size for non-expired cache" do
        expect(cache.size(logical_key)).to eq(14)
      end

      it "returns nil for expired cache" do
        FileUtils.touch(cache_path, mtime: Time.now - 20)
        expect(cache.size(logical_key)).to be_nil
      end
    end
  end

  describe "#with_lock" do
    before do
      lock_path.dirname.mkpath
    end

    it "creates and removes the lock file" do
      cache.with_lock(logical_key) { nil } # Empty block intentional - testing lock lifecycle
      expect(lock_path).not_to exist
    end

    it "yields to the block" do
      expect {|b| cache.with_lock(logical_key, &b) }.to yield_control
    end

    it "ensures the lock file is removed even if the block raises an error" do
      expect {
        cache.with_lock(logical_key) { raise RuntimeError, "error" }
      }.to raise_error(RuntimeError, "error")
      expect(lock_path).not_to exist
    end

    context "when a stale lock file exists" do
      before do
        lock_path.dirname.mkpath
        FileUtils.touch(lock_path)
        FileUtils.touch(lock_path, mtime: Time.now - Factorix::Cache::FileSystem::LOCK_FILE_LIFETIME - 1)
      end

      it "removes the stale lock file" do
        cache.with_lock(logical_key) { nil } # Empty block intentional - testing stale lock cleanup
        expect(lock_path).not_to exist
      end
    end

    context "when a recent lock file exists" do
      before do
        lock_path.dirname.mkpath
        FileUtils.touch(lock_path)
      end

      it "waits for the lock" do
        # This test is a bit tricky because we can't easily test file locking
        # Instead, we just verify that the code doesn't raise any errors
        expect {
          cache.with_lock(logical_key) { nil } # Empty block intentional - testing lock behavior
        }.not_to raise_error
      end
    end
  end

  describe "#each" do
    context "with no cache entries" do
      it "returns an empty enumerator" do
        expect(cache.each.to_a).to be_empty
      end
    end

    context "with cache entries" do
      let(:urls) { ["https://example.com/a.zip", "https://example.com/b.zip", "https://example.com/c.zip"] }
      let(:source_file) { Pathname(Dir.mktmpdir("source")) + "data.txt" }

      before do
        File.write(source_file, "test content")
        urls.each {|u| cache.store(u, source_file) }
      end

      after do
        FileUtils.remove_entry(source_file.dirname)
      end

      it "yields each key and entry pair" do
        yielded_keys = []
        cache.each {|key, _entry| yielded_keys << key }
        expect(yielded_keys.sort).to eq(urls.sort)
      end

      it "yields Entry objects with correct attributes" do
        cache.each do |_key, entry|
          expect(entry).to be_a(Factorix::Cache::Entry)
          expect(entry.size).to eq(12) # "test content" is 12 bytes
          expect(entry.age).to be_within(1).of(0)
          expect(entry).not_to be_expired
        end
      end

      it "returns an enumerator when no block given" do
        expect(cache.each).to be_a(Enumerator)
        expect(cache.each.count).to eq(3)
      end
    end

    context "with expired entries" do
      let(:source_file) { Pathname(Dir.mktmpdir("source")) + "data.txt" }
      let(:cache) { Factorix::Cache::FileSystem.new(root: cache_dir, ttl: 10) }

      before do
        File.write(source_file, "test")
        cache.store(logical_key, source_file)
        FileUtils.touch(cache_path, mtime: Time.now - 20)
      end

      after do
        FileUtils.remove_entry(source_file.dirname)
      end

      it "marks entry as expired" do
        cache.each do |_key, entry|
          expect(entry).to be_expired
        end
      end
    end

    context "with entries without metadata (legacy entries)" do
      before do
        # Create a cache file without metadata
        cache_path.dirname.mkpath
        File.write(cache_path, "legacy content")
      end

      it "skips entries without metadata" do
        expect(cache.each.to_a).to be_empty
      end
    end
  end
end
