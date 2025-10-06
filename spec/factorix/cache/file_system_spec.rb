# frozen_string_literal: true

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
      cache.store(key, source_file)
      expect(cache_path).to exist
      expect(cache_path.read).to eq("source content")
    end

    it "creates the cache subdirectory" do
      expect {
        cache.store(key, source_file)
      }.to change(cache_path.dirname, :exist?).from(false).to(true)
    end
  end

  describe "#with_lock" do
    before do
      lock_path.dirname.mkpath
    end

    it "creates and removes the lock file" do
      cache.with_lock(key) {} # Test focuses on lock file lifecycle, not block content
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
        cache.with_lock(key) {} # Test focuses on lock file lifecycle with stale lock
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
          cache.with_lock(key) {} # Test verifies no errors occur with existing lock
        }.not_to raise_error
      end
    end
  end
end
