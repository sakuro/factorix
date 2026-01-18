# frozen_string_literal: true

require "json"

RSpec.describe Factorix::CLI::Commands::Cache::Stat do
  let(:cache_dir) { Pathname(Dir.mktmpdir) }

  before do
    # Set up test cache directories
    %i[download api info_json].each do |name|
      dir = cache_dir / name.to_s
      dir.mkpath
      allow(Factorix.config.cache.public_send(name)).to receive(:dir).and_return(dir)
    end
  end

  after do
    FileUtils.rm_rf(cache_dir)
  end

  describe "#call" do
    context "with empty caches" do
      it "outputs statistics in text format" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat)

        expect(result.stdout).to include("download:")
        expect(result.stdout).to include("api:")
        expect(result.stdout).to include("info_json:")
        expect(result.stdout).to include("Entries:        0 / 0")
        expect(result.stdout).to include("Size:           0 B")
      end

      it "outputs statistics in JSON format" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat, %w[--json])

        json = JSON.parse(result.stdout, symbolize_names: true)
        expect(json.keys).to contain_exactly(:download, :api, :info_json)
        expect(json[:download][:entries]).to eq({total: 0, valid: 0, expired: 0})
      end
    end

    context "with cache entries" do
      before do
        # Create some test cache files
        download_dir = cache_dir / "download"
        (download_dir / "ab").mkpath
        (download_dir / "ab" / "cdef1234").write("test content 1")
        (download_dir / "ab" / "cdef5678").write("test content 2 longer")
      end

      it "counts entries correctly" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat, %w[--json])

        json = JSON.parse(result.stdout, symbolize_names: true)
        expect(json[:download][:entries][:total]).to eq(2)
        expect(json[:download][:entries][:valid]).to eq(2)
      end

      it "calculates size statistics" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat, %w[--json])

        json = JSON.parse(result.stdout, symbolize_names: true)
        expect(json[:download][:size][:total]).to eq(35) # 14 + 21 bytes
        expect(json[:download][:size][:min]).to eq(14)
        expect(json[:download][:size][:max]).to eq(21)
      end
    end

    context "with expired entries" do
      before do
        api_dir = cache_dir / "api"
        (api_dir / "ab").mkpath

        # Create an old file (expired)
        old_file = api_dir / "ab" / "old_entry"
        old_file.write("old content")
        FileUtils.touch(old_file, mtime: Time.now - 7200) # 2 hours ago

        # Create a new file (valid)
        new_file = api_dir / "ab" / "new_entry"
        new_file.write("new content")
      end

      it "distinguishes valid and expired entries" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat, %w[--json])

        json = JSON.parse(result.stdout, symbolize_names: true)
        # api cache has TTL of 3600 seconds (1 hour)
        expect(json[:api][:entries][:total]).to eq(2)
        expect(json[:api][:entries][:valid]).to eq(1)
        expect(json[:api][:entries][:expired]).to eq(1)
      end
    end

    context "with lock files" do
      before do
        download_dir = cache_dir / "download"
        (download_dir / "ab").mkpath

        # Create a stale lock file
        lock_file = download_dir / "ab" / "test.lock"
        lock_file.write("")
        # Make it older than LOCK_FILE_LIFETIME (3600 seconds)
        FileUtils.touch(lock_file, mtime: Time.now - 7200)
      end

      it "counts stale locks" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat, %w[--json])

        json = JSON.parse(result.stdout, symbolize_names: true)
        expect(json[:download][:stale_locks]).to eq(1)
      end

      it "does not count lock files as cache entries" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat, %w[--json])

        json = JSON.parse(result.stdout, symbolize_names: true)
        expect(json[:download][:entries][:total]).to eq(0)
      end
    end
  end

  describe "text output formatting" do
    it "formats TTL as duration when set" do
      result = run_command(Factorix::CLI::Commands::Cache::Stat)

      expect(result.stdout).to include("TTL:            1h 0m") # api cache has 3600s TTL
    end

    it "formats TTL as unlimited when nil" do
      result = run_command(Factorix::CLI::Commands::Cache::Stat)

      expect(result.stdout).to include("TTL:            unlimited") # download cache has nil TTL
    end

    it "formats compression setting" do
      result = run_command(Factorix::CLI::Commands::Cache::Stat)

      # download has nil (disabled), api/info_json have 0 (always)
      expect(result.stdout).to include("Compression:    disabled")
      expect(result.stdout).to include("Compression:    enabled (always)")
    end

    it "formats sizes using binary prefixes" do
      download_dir = cache_dir / "download"
      (download_dir / "ab").mkpath
      # Create a file larger than 1 KiB
      (download_dir / "ab" / "large_file").write("x" * 2048)

      result = run_command(Factorix::CLI::Commands::Cache::Stat)

      expect(result.stdout).to include("KiB")
    end
  end
end
