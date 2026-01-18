# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Cache::Evict do
  let(:command) { Factorix::CLI::Commands::Cache::Evict.new }
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
    context "without any option" do
      it "raises an error" do
        expect { run_command(command) }.to raise_error(Factorix::InvalidArgumentError, /One of --all, --expired, or --older-than must be specified/)
      end
    end

    context "with multiple options" do
      it "raises an error" do
        expect { run_command(command, %w[--all --expired]) }.to raise_error(Factorix::InvalidArgumentError, /Only one of --all, --expired, or --older-than can be specified/)
      end
    end

    context "with --all option" do
      before do
        download_dir = cache_dir / "download"
        (download_dir / "ab").mkpath
        (download_dir / "ab" / "cdef1234").write("test content 1")
        (download_dir / "ab" / "cdef5678").write("test content 2")
      end

      it "removes all entries" do
        result = run_command(command, %w[--all])

        expect(result.stdout).to match(/download.*2 entries removed/)
        expect((cache_dir / "download").glob("**/*").select(&:file?)).to be_empty
      end

      it "respects cache name argument" do
        api_dir = cache_dir / "api"
        (api_dir / "ab").mkpath
        (api_dir / "ab" / "api_entry").write("api content")

        result = run_command(command, %w[download --all])

        expect(result.stdout).to match(/download/)
        expect(result.stdout).not_to match(/\bapi\s*:/)
        # api cache should still have its entry
        expect(cache_dir / "api" / "ab" / "api_entry").to exist
      end
    end

    context "with --expired option" do
      before do
        api_dir = cache_dir / "api"
        (api_dir / "ab").mkpath

        # Create an expired file (older than TTL of 3600s)
        old_file = api_dir / "ab" / "old_entry"
        old_file.write("old content")
        FileUtils.touch(old_file, mtime: Time.now - 7200)

        # Create a valid file
        new_file = api_dir / "ab" / "new_entry"
        new_file.write("new content")
      end

      it "removes only expired entries" do
        result = run_command(command, %w[--expired])

        expect(result.stdout).to match(/api.*1 entries removed/)
        expect(cache_dir / "api" / "ab" / "old_entry").not_to exist
        expect(cache_dir / "api" / "ab" / "new_entry").to exist
      end

      it "does not remove entries from caches without TTL" do
        download_dir = cache_dir / "download"
        (download_dir / "ab").mkpath
        old_file = download_dir / "ab" / "old_download"
        old_file.write("old download content")
        FileUtils.touch(old_file, mtime: Time.now - 86400) # 1 day old

        result = run_command(command, %w[--expired])

        # download cache has no TTL, so no entries should be removed
        expect(result.stdout).to match(/download.*0 entries removed/)
        expect(cache_dir / "download" / "ab" / "old_download").to exist
      end
    end

    context "with --older-than option" do
      before do
        download_dir = cache_dir / "download"
        (download_dir / "ab").mkpath

        # Create an old file
        old_file = download_dir / "ab" / "old_entry"
        old_file.write("old content")
        FileUtils.touch(old_file, mtime: Time.now - 86400) # 1 day old

        # Create a new file
        new_file = download_dir / "ab" / "new_entry"
        new_file.write("new content")
      end

      it "removes entries older than specified age" do
        result = run_command(command, %w[--older-than=12h])

        expect(result.stdout).to match(/download.*1 entries removed/)
        expect(cache_dir / "download" / "ab" / "old_entry").not_to exist
        expect(cache_dir / "download" / "ab" / "new_entry").to exist
      end

      it "parses various age formats" do
        # Test that parsing works for different formats
        expect { run_command(command, %w[--older-than=30s]) }.not_to raise_error
        expect { run_command(command, %w[--older-than=5m]) }.not_to raise_error
        expect { run_command(command, %w[--older-than=2h]) }.not_to raise_error
        expect { run_command(command, %w[--older-than=7d]) }.not_to raise_error
      end

      it "raises error for invalid age format" do
        expect { run_command(command, %w[--older-than=invalid]) }.to raise_error(Factorix::InvalidArgumentError, /Invalid age format/)
        expect { run_command(command, %w[--older-than=10]) }.to raise_error(Factorix::InvalidArgumentError, /Invalid age format/)
        expect { run_command(command, %w[--older-than=10w]) }.to raise_error(Factorix::InvalidArgumentError, /Invalid age format/)
      end
    end

    context "with unknown cache name" do
      it "raises an error" do
        pending "dry-cli validates values before reaching resolve_cache_names"
        expect { run_command(command, %w[unknown --all]) }.to raise_error(Factorix::InvalidArgumentError, /Unknown cache: unknown/)
      end
    end

    context "with lock files" do
      before do
        download_dir = cache_dir / "download"
        (download_dir / "ab").mkpath
        (download_dir / "ab" / "entry").write("content")
        (download_dir / "ab" / "entry.lock").write("")
      end

      it "does not remove lock files" do
        run_command(command, %w[--all])

        expect(cache_dir / "download" / "ab" / "entry").not_to exist
        expect(cache_dir / "download" / "ab" / "entry.lock").to exist
      end
    end
  end

  describe "output format" do
    before do
      download_dir = cache_dir / "download"
      (download_dir / "ab").mkpath
      (download_dir / "ab" / "entry").write("x" * 2048) # 2 KiB
    end

    it "formats sizes using binary prefixes" do
      result = run_command(command, %w[--all])

      expect(result.stdout).to match(/KiB/)
    end
  end
end
