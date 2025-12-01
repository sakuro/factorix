# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Cache::Evict do
  include_context "with suppressed output"

  let(:command) { Factorix::CLI::Commands::Cache::Evict.new }
  let(:cache_dir) { Pathname(Dir.mktmpdir) }

  before do
    # Set up test cache directories
    %i[download api info_json].each do |name|
      dir = cache_dir / name.to_s
      dir.mkpath
      allow(Factorix::Application.config.cache.public_send(name)).to receive(:dir).and_return(dir)
    end
  end

  after do
    FileUtils.rm_rf(cache_dir)
  end

  describe "#call" do
    context "without any option" do
      it "raises an error" do
        expect { command.call }.to raise_error(Factorix::InvalidArgumentError, /One of --all, --expired, or --older-than must be specified/)
      end
    end

    context "with multiple options" do
      it "raises an error" do
        expect { command.call(all: true, expired: true) }.to raise_error(Factorix::InvalidArgumentError, /Only one of --all, --expired, or --older-than can be specified/)
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
        command.call(all: true)

        expect(command).to have_received(:say).with(/download.*2 entries removed/, prefix: :info)
        expect((cache_dir / "download").glob("**/*").select(&:file?)).to be_empty
      end

      it "respects cache name argument" do
        api_dir = cache_dir / "api"
        (api_dir / "ab").mkpath
        (api_dir / "ab" / "api_entry").write("api content")

        command.call(caches: ["download"], all: true)

        expect(command).to have_received(:say).with(/download/, prefix: :info)
        expect(command).not_to have_received(:say).with(/\bapi\s*:/, prefix: :info)
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
        command.call(expired: true)

        expect(command).to have_received(:say).with(/api.*1 entries removed/, prefix: :info)
        expect(cache_dir / "api" / "ab" / "old_entry").not_to exist
        expect(cache_dir / "api" / "ab" / "new_entry").to exist
      end

      it "does not remove entries from caches without TTL" do
        download_dir = cache_dir / "download"
        (download_dir / "ab").mkpath
        old_file = download_dir / "ab" / "old_download"
        old_file.write("old download content")
        FileUtils.touch(old_file, mtime: Time.now - 86400) # 1 day old

        command.call(expired: true)

        # download cache has no TTL, so no entries should be removed
        expect(command).to have_received(:say).with(/download.*0 entries removed/, prefix: :info)
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
        command.call(older_than: "12h")

        expect(command).to have_received(:say).with(/download.*1 entries removed/, prefix: :info)
        expect(cache_dir / "download" / "ab" / "old_entry").not_to exist
        expect(cache_dir / "download" / "ab" / "new_entry").to exist
      end

      it "parses various age formats" do
        # Test that parsing works for different formats
        expect { command.call(older_than: "30s") }.not_to raise_error
        expect { command.call(older_than: "5m") }.not_to raise_error
        expect { command.call(older_than: "2h") }.not_to raise_error
        expect { command.call(older_than: "7d") }.not_to raise_error
      end

      it "raises error for invalid age format" do
        expect { command.call(older_than: "invalid") }.to raise_error(Factorix::InvalidArgumentError, /Invalid age format/)
        expect { command.call(older_than: "10") }.to raise_error(Factorix::InvalidArgumentError, /Invalid age format/)
        expect { command.call(older_than: "10w") }.to raise_error(Factorix::InvalidArgumentError, /Invalid age format/)
      end
    end

    context "with unknown cache name" do
      it "raises an error" do
        expect { command.call(caches: ["unknown"], all: true) }.to raise_error(Factorix::InvalidArgumentError, /Unknown cache: unknown/)
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
        command.call(all: true)

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
      command.call(all: true)

      expect(command).to have_received(:say).with(/KiB/, prefix: :info).at_least(:once)
    end
  end
end
