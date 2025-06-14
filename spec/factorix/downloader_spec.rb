# frozen_string_literal: true

require "pathname"
require "tmpdir"
require_relative "../../lib/factorix/downloader"

RSpec.describe Factorix::Downloader do
  let(:cache_storage) { instance_double(Factorix::Cache::FileSystem) }
  let(:http_client) { instance_double(Factorix::HttpClient) }
  let(:downloader) { Factorix::Downloader.new(cache_storage:, http_client:) }
  let(:uri) { URI("https://example.com/file.zip") }
  let(:output_dir) { Pathname(Dir.mktmpdir("output")) }
  let(:output) { output_dir.join("file.zip") }
  let(:cache_key) { "cache_key" }

  around do |example|
    # テスト前の一時ディレクトリのクリーンアップ
    Dir.glob(File.join(Dir.tmpdir, "factorix*")).each do |dir|
      FileUtils.remove_entry(dir) rescue nil
    end

    # テストの実行
    example.run

    # テスト後の一時ディレクトリのクリーンアップ
    Dir.glob(File.join(Dir.tmpdir, "factorix*")).each do |dir|
      FileUtils.remove_entry(dir) rescue nil
    end
  end

  before do
    allow(cache_storage).to receive(:key_for).with("https://example.com/file.zip").and_return(cache_key)
    allow(http_client).to receive(:download)
  end

  after do
    FileUtils.remove_entry(output_dir)
  end

  describe "#download" do
    context "when the file is cached" do
      before do
        allow(cache_storage).to receive(:fetch).with(cache_key, output).and_return(true)
      end

      it "fetches the file from cache" do
        downloader.download(uri, output)
        expect(cache_storage).to have_received(:fetch).with(cache_key, output).once
      end

      it "does not download the file" do
        downloader.download(uri, output)
        expect(http_client).not_to have_received(:download)
      end
    end

    context "when the file is not cached" do
      before do
        allow(cache_storage).to receive(:fetch).with(cache_key, output).and_return(false)
        allow(cache_storage).to receive(:with_lock).with(cache_key).and_yield
        allow(cache_storage).to receive(:store)
      end

      it "downloads the file" do
        downloader.download(uri, output)
        expect(http_client).to have_received(:download).with(uri, kind_of(Pathname))
      end

      it "stores the file in cache" do
        downloader.download(uri, output)
        expect(cache_storage).to have_received(:store).with(cache_key, kind_of(Pathname))
      end

      it "fetches the file from cache after download" do
        # fetch is called three times:
        # 1. Initial check before acquiring the lock
        # 2. Second check after acquiring the lock (in case another process completed the download)
        # 3. Final fetch to copy the downloaded file from cache to the output path
        allow(cache_storage).to receive(:fetch).with(cache_key, output).and_return(false)
        downloader.download(uri, output)
        expect(cache_storage).to have_received(:fetch).with(cache_key, output).exactly(3).times
      end

      context "when another process is downloading" do
        before do
          # First fetch fails, then another process completes the download during lock,
          # making the second fetch succeed
          fetch_results = [false, true]
          allow(cache_storage).to receive(:fetch) do
            fetch_results.shift
          end
        end

        it "does not download the file if it appears in cache" do
          downloader.download(uri, output)
          expect(http_client).not_to have_received(:download)
        end
      end
    end

    context "with invalid URI" do
      it "raises ArgumentError for non-HTTP URI" do
        expect { downloader.download(Object.new, output) }.to raise_error(ArgumentError, "URL must be HTTP or HTTPS")
      end
    end

    context "when download fails" do
      before do
        allow(cache_storage).to receive(:fetch).with(cache_key, output).and_return(false)
        allow(cache_storage).to receive(:with_lock).with(cache_key).and_yield
        allow(http_client).to receive(:download).and_raise(Factorix::HTTPClientError)
      end

      it "raises DownloadError" do
        expect { downloader.download(uri, output) }.to raise_error(Factorix::HTTPClientError)
      end

      it "cleans up temporary files" do
        begin
          downloader.download(uri, output)
        rescue Factorix::HTTPClientError
          # Expected exception
        end

        # Verify that temporary directories are removed
        temp_dirs = Dir.glob(File.join(Dir.tmpdir, "factorix*"))
        expect(temp_dirs).to be_empty
      end
    end
  end
end
