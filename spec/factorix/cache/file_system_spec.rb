# frozen_string_literal: true

require "fileutils"
require "pathname"
require "tmpdir"

RSpec.describe Factorix::Cache::FileSystem do
  let(:cache_dir) { Pathname(Dir.mktmpdir("cache")) }
  let(:cache) { Factorix::Cache::FileSystem.new(cache_dir) }
  let(:url) { "https://example.com/file.zip" }
  let(:key) { cache.key_for(url) }
  let(:cache_path) { cache_dir.join(key[0, 2], key[2..]) }
  let(:lock_path) { cache_path.sub_ext(".lock") }

  after do
    FileUtils.remove_entry(cache_dir)
  end

  describe "#initialize" do
    it "creates the cache directory if it does not exist" do
      FileUtils.remove_entry(cache_dir)
      expect {
        Factorix::Cache::FileSystem.new(cache_dir)
      }.to change(cache_dir, :exist?).from(false).to(true)
    end

    it "accepts ttl parameter" do
      cache_with_ttl = Factorix::Cache::FileSystem.new(cache_dir, ttl: 3600)
      expect(cache_with_ttl).to be_a(Factorix::Cache::FileSystem)
    end

    it "accepts max_file_size parameter" do
      cache_with_limit = Factorix::Cache::FileSystem.new(cache_dir, max_file_size: 1024 * 1024)
      expect(cache_with_limit).to be_a(Factorix::Cache::FileSystem)
    end
  end

  describe "#key_for" do
    it "generates a SHA1 hash of the URL" do
      expect(key).to match(/\A[0-9a-f]{40}\z/)
      expect(key).to eq(Digest::SHA1.hexdigest(url))
    end
  end

  describe "#exist?" do
    context "when the cache file exists" do
      before do
        cache_path.dirname.mkpath
        FileUtils.touch(cache_path)
      end

      it "returns true" do
        expect(cache.exist?(key)).to be true
      end
    end

    context "when the cache file does not exist" do
      it "returns false" do
        expect(cache.exist?(key)).to be false
      end
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::FileSystem.new(cache_dir, ttl: 10) }

      before do
        cache_path.dirname.mkpath
        FileUtils.touch(cache_path)
      end

      it "returns true for non-expired cache" do
        expect(cache.exist?(key)).to be true
      end

      it "returns false for expired cache" do
        FileUtils.touch(cache_path, mtime: Time.now - 20)
        expect(cache.exist?(key)).to be false
      end
    end
  end

  describe "#fetch" do
    let(:output_file) { Pathname(Dir.mktmpdir("output")).join("file.zip") }

    after do
      FileUtils.remove_entry(output_file.dirname)
    end

    context "when the cache file exists" do
      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "copies the cache file to the output path" do
        expect(cache.fetch(key, output_file)).to be true
        expect(output_file.read).to eq("cached content")
      end
    end

    context "when the cache file does not exist" do
      it "returns false" do
        expect(cache.fetch(key, output_file)).to be false
        expect(output_file).not_to exist
      end
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::FileSystem.new(cache_dir, ttl: 10) }

      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "returns false for expired cache" do
        FileUtils.touch(cache_path, mtime: Time.now - 20)
        expect(cache.fetch(key, output_file)).to be false
        expect(output_file).not_to exist
      end
    end
  end

  describe "#read" do
    context "when the cache file exists" do
      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "reads the cache file as a binary string by default" do
        content = cache.read(key)
        expect(content).to eq("cached content")
        expect(content.encoding).to eq(Encoding::ASCII_8BIT)
      end

      it "reads the cache file with specified encoding" do
        File.write(cache_path, "日本語コンテンツ")
        content = cache.read(key, encoding: Encoding::UTF_8)
        expect(content).to eq("日本語コンテンツ")
        expect(content.encoding).to eq(Encoding::UTF_8)
      end
    end

    context "when the cache file does not exist" do
      it "returns nil" do
        expect(cache.read(key)).to be_nil
      end
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::FileSystem.new(cache_dir, ttl: 10) }

      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "returns nil for expired cache" do
        FileUtils.touch(cache_path, mtime: Time.now - 20)
        expect(cache.read(key)).to be_nil
      end
    end
  end

  describe "#store" do
    let(:source_file) { Pathname(Dir.mktmpdir("source")).join("file.zip") }

    before do
      File.write(source_file, "source content")
    end

    after do
      FileUtils.remove_entry(source_file.dirname)
    end

    it "copies the source file to the cache" do
      expect(cache.store(key, source_file)).to be true
      expect(cache_path).to exist
      expect(cache_path.read).to eq("source content")
    end

    it "creates the cache subdirectory" do
      expect {
        cache.store(key, source_file)
      }.to change(cache_path.dirname, :exist?).from(false).to(true)
    end

    context "with max_file_size limit" do
      let(:cache) { Factorix::Cache::FileSystem.new(cache_dir, max_file_size: 10) }

      it "stores files within the limit" do
        small_file = Pathname(Dir.mktmpdir("small")).join("small.txt")
        File.write(small_file, "small")

        expect(cache.store(key, small_file)).to be true
        expect(cache_path).to exist

        FileUtils.remove_entry(small_file.dirname)
      end

      it "skips caching files exceeding the limit" do
        large_file = Pathname(Dir.mktmpdir("large")).join("large.txt")
        File.write(large_file, "a" * 100)

        expect(cache.store(key, large_file)).to be false
        expect(cache_path).not_to exist

        FileUtils.remove_entry(large_file.dirname)
      end
    end
  end

  describe "#delete" do
    context "when the cache file exists" do
      before do
        cache_path.dirname.mkpath
        FileUtils.touch(cache_path)
      end

      it "deletes the cache file and returns true" do
        expect(cache.delete(key)).to be true
        expect(cache_path).not_to exist
      end
    end

    context "when the cache file does not exist" do
      it "returns false" do
        expect(cache.delete(key)).to be false
      end
    end
  end

  describe "#clear" do
    before do
      # Create multiple cache entries
      3.times do |i|
        test_key = cache.key_for("https://example.com/file#{i}.zip")
        test_path = cache_dir.join(test_key[0, 2], test_key[2..])
        test_path.dirname.mkpath
        FileUtils.touch(test_path)
      end
    end

    it "removes all cache files" do
      cache.clear

      cache_files = cache_dir.glob("**/*").select(&:file?)
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
        age = cache.age(key)
        expect(age).to be_within(1).of(100)
      end
    end

    context "when the cache file does not exist" do
      it "returns nil" do
        expect(cache.age(key)).to be_nil
      end
    end
  end

  describe "#expired?" do
    context "without TTL" do
      it "always returns false" do
        expect(cache.expired?(key)).to be false
      end
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::FileSystem.new(cache_dir, ttl: 50) }

      before do
        cache_path.dirname.mkpath
        FileUtils.touch(cache_path, mtime: Time.now - 100)
      end

      it "returns true for expired cache" do
        expect(cache.expired?(key)).to be true
      end

      it "returns false for non-expired cache" do
        FileUtils.touch(cache_path, mtime: Time.now - 30)
        expect(cache.expired?(key)).to be false
      end
    end

    context "when cache file does not exist" do
      let(:cache) { Factorix::Cache::FileSystem.new(cache_dir, ttl: 50) }

      it "returns false" do
        expect(cache.expired?(key)).to be false
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
        expect(cache.size(key)).to eq(14) # "cached content" is 14 bytes
      end
    end

    context "when the cache file does not exist" do
      it "returns nil" do
        expect(cache.size(key)).to be_nil
      end
    end

    context "with TTL" do
      let(:cache) { Factorix::Cache::FileSystem.new(cache_dir, ttl: 10) }

      before do
        cache_path.dirname.mkpath
        File.write(cache_path, "cached content")
      end

      it "returns the size for non-expired cache" do
        expect(cache.size(key)).to eq(14)
      end

      it "returns nil for expired cache" do
        FileUtils.touch(cache_path, mtime: Time.now - 20)
        expect(cache.size(key)).to be_nil
      end
    end
  end

  describe "#with_lock" do
    before do
      lock_path.dirname.mkpath
    end

    it "creates and removes the lock file" do
      cache.with_lock(key) { nil } # Empty block intentional - testing lock lifecycle
      expect(lock_path).not_to exist
    end

    it "yields to the block" do
      expect {|b| cache.with_lock(key, &b) }.to yield_control
    end

    it "ensures the lock file is removed even if the block raises an error" do
      expect {
        cache.with_lock(key) { raise RuntimeError, "error" }
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
        cache.with_lock(key) { nil } # Empty block intentional - testing stale lock cleanup
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
          cache.with_lock(key) { nil } # Empty block intentional - testing lock behavior
        }.not_to raise_error
      end
    end
  end
end
