# frozen_string_literal: true

require "pathname"
require "tmpdir"

RSpec.describe Factorix::Transfer::Downloader do
  let(:download_cache) { instance_double(Factorix::Cache::FileSystem) }
  let(:http) { instance_double(Factorix::Transfer::HTTP) }
  let(:downloader) { Factorix::Transfer::Downloader.new(download_cache:, http:) }
  let(:uri) { URI("https://example.com/file.zip") }
  let(:output_dir) { Pathname(Dir.mktmpdir("output")) }
  let(:output) { output_dir.join("file.zip") }
  let(:cache_key) { "cache_key" }

  around do |example|
    Dir.glob(File.join(Dir.tmpdir, "factorix*")).each do |dir|
      FileUtils.remove_entry(dir)
    rescue
      nil
    end

    example.run

    Dir.glob(File.join(Dir.tmpdir, "factorix*")).each do |dir|
      FileUtils.remove_entry(dir)
    rescue
      nil
    end
  end

  before do
    allow(download_cache).to receive(:key_for).with("https://example.com/file.zip").and_return(cache_key)
    allow(http).to receive(:download).and_return(nil)
  end

  after do
    FileUtils.remove_entry(output_dir)
  end

  describe "#download" do
    context "when the file is cached" do
      before do
        allow(download_cache).to receive(:fetch).with(cache_key, output).and_return(true)
      end

      it "fetches the file from cache" do
        downloader.download(uri, output)
        expect(download_cache).to have_received(:fetch).with(cache_key, output).once
      end

      it "does not download the file" do
        downloader.download(uri, output)
        expect(http).not_to have_received(:download)
      end
    end

    context "when the file is not cached" do
      before do
        allow(download_cache).to receive(:fetch).with(cache_key, output).and_return(false)
        allow(download_cache).to receive(:with_lock).with(cache_key).and_yield
        allow(download_cache).to receive(:store)
      end

      it "downloads the file" do
        downloader.download(uri, output)
        expect(http).to have_received(:download).with(uri, kind_of(Pathname))
      end

      it "stores the file in cache" do
        downloader.download(uri, output)
        expect(download_cache).to have_received(:store).with(cache_key, kind_of(Pathname))
      end

      it "fetches the file from cache after download" do
        allow(download_cache).to receive(:fetch).with(cache_key, output).and_return(false)
        downloader.download(uri, output)
        expect(download_cache).to have_received(:fetch).with(cache_key, output).exactly(3).times
      end

      context "when another process is downloading" do
        before do
          fetch_results = [false, true]
          allow(download_cache).to receive(:fetch) do
            fetch_results.shift
          end
        end

        it "does not download the file if it appears in cache" do
          downloader.download(uri, output)
          expect(http).not_to have_received(:download)
        end
      end
    end

    context "with invalid URI" do
      it "raises ArgumentError for HTTP URI" do
        http_uri = URI("http://example.com/file.zip")
        expect { downloader.download(http_uri, output) }.to raise_error(ArgumentError, "URL must be HTTPS")
      end

      it "raises ArgumentError for FTP URI" do
        ftp_uri = URI("ftp://example.com/file.zip")
        expect { downloader.download(ftp_uri, output) }.to raise_error(ArgumentError, "URL must be HTTPS")
      end
    end

    context "when download fails" do
      before do
        allow(download_cache).to receive(:fetch).with(cache_key, output).and_return(false)
        allow(download_cache).to receive(:with_lock).with(cache_key).and_yield
        allow(http).to receive(:download).and_raise(Factorix::HTTPClientError.new("404 Not Found"))
      end

      it "raises HTTPClientError" do
        expect { downloader.download(uri, output) }.to raise_error(Factorix::HTTPClientError)
      end

      it "cleans up temporary files" do
        begin
          downloader.download(uri, output)
        rescue Factorix::HTTPClientError
          # Expected exception
        end

        temp_dirs = Dir.glob(File.join(Dir.tmpdir, "factorix*"))
        expect(temp_dirs).to be_empty
      end
    end
  end
end
