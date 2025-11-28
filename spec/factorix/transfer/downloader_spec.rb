# frozen_string_literal: true

require "pathname"
require "tmpdir"

RSpec.describe Factorix::Transfer::Downloader do
  let(:cache) { instance_double(Factorix::Cache::FileSystem) }
  let(:client) { instance_double(Factorix::HTTP::Client) }
  let(:downloader) { Factorix::Transfer::Downloader.new(cache:, client:) }
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
    allow(cache).to receive(:key_for).with("https://example.com/file.zip").and_return(cache_key)
    allow(cache).to receive(:size).and_return(1024)
    allow(client).to receive(:get)
  end

  after do
    FileUtils.remove_entry(output_dir)
  end

  describe "#download" do
    context "when the file is cached" do
      let(:cached_content) { "cached file content" }

      before do
        allow(cache).to receive(:fetch).with(cache_key, output) do
          output.write(cached_content)
          true
        end
      end

      it "fetches the file from cache" do
        downloader.download(uri, output)
        expect(cache).to have_received(:fetch).with(cache_key, output).once
      end

      it "does not download the file" do
        downloader.download(uri, output)
        expect(client).not_to have_received(:get)
      end

      context "with SHA1 verification" do
        let(:correct_sha1) { Digest(:SHA1).hexdigest(cached_content) }
        let(:wrong_sha1) { "0" * 40 }

        it "succeeds when SHA1 matches" do
          expect { downloader.download(uri, output, expected_sha1: correct_sha1) }.not_to raise_error
        end

        context "when SHA1 does not match" do
          let(:fresh_content) { "fresh file content" }
          let(:fresh_sha1) { Digest(:SHA1).hexdigest(fresh_content) }

          before do
            allow(cache).to receive(:delete).with(cache_key)
            allow(cache).to receive(:with_lock).with(cache_key).and_yield
            allow(cache).to receive(:store)

            # After cache invalidation, fetch returns false
            fetch_count = 0
            allow(cache).to receive(:fetch).with(cache_key, output) do
              fetch_count += 1
              if fetch_count == 1
                # First call: cached content (corrupted)
                output.write(cached_content)
                true
              else
                # Subsequent calls: cache miss (after invalidation)
                false
              end
            end

            # Mock client.get for re-download
            allow(client).to receive(:get) do |&block|
              response = instance_double(Net::HTTPResponse)
              allow(response).to receive(:[]).with("Content-Length").and_return(fresh_content.bytesize.to_s)
              allow(response).to receive(:read_body).and_yield(fresh_content)
              block&.call(response)
            end
          end

          it "invalidates cache and re-downloads" do
            downloader.download(uri, output, expected_sha1: fresh_sha1)

            expect(cache).to have_received(:delete).with(cache_key)
            expect(client).to have_received(:get).with(uri)
          end

          it "raises DigestMismatchError when re-downloaded file also fails verification" do
            expect { downloader.download(uri, output, expected_sha1: wrong_sha1) }
              .to raise_error(Factorix::DigestMismatchError, /SHA1 mismatch/)
          end
        end
      end
    end

    context "when the file is not cached" do
      let(:response_body) { "file content" }

      before do
        allow(cache).to receive(:fetch).with(cache_key, output).and_return(false)
        allow(cache).to receive(:with_lock).with(cache_key).and_yield
        allow(cache).to receive(:store)

        # Mock client.get to yield a response with streaming
        allow(client).to receive(:get) do |&block|
          response = instance_double(Net::HTTPResponse)
          allow(response).to receive(:[]).with("Content-Length").and_return(response_body.bytesize.to_s)
          allow(response).to receive(:read_body).and_yield(response_body)
          block&.call(response)
        end
      end

      it "downloads the file" do
        downloader.download(uri, output)
        expect(client).to have_received(:get).with(uri)
      end

      it "stores the file in cache" do
        downloader.download(uri, output)
        expect(cache).to have_received(:store).with(cache_key, kind_of(Pathname))
      end

      it "fetches the file from cache after download" do
        allow(cache).to receive(:fetch).with(cache_key, output).and_return(false)
        downloader.download(uri, output)
        expect(cache).to have_received(:fetch).with(cache_key, output).exactly(3).times
      end

      context "when another process is downloading" do
        before do
          fetch_results = [false, true]
          allow(cache).to receive(:fetch) do
            fetch_results.shift
          end
        end

        it "does not download the file if it appears in cache" do
          downloader.download(uri, output)
          expect(client).not_to have_received(:get)
        end
      end

      context "with SHA1 verification" do
        let(:response_body) { "file content" }
        let(:correct_sha1) { Digest(:SHA1).hexdigest(response_body) }
        let(:wrong_sha1) { "0" * 40 }

        it "succeeds when SHA1 matches" do
          expect { downloader.download(uri, output, expected_sha1: correct_sha1) }.not_to raise_error
          expect(cache).to have_received(:store)
        end

        it "raises DigestMismatchError when SHA1 does not match" do
          expect { downloader.download(uri, output, expected_sha1: wrong_sha1) }
            .to raise_error(Factorix::DigestMismatchError, /SHA1 mismatch/)
        end

        it "does not store in cache when SHA1 does not match" do
          begin
            downloader.download(uri, output, expected_sha1: wrong_sha1)
          rescue Factorix::DigestMismatchError
            # Expected exception
          end
          expect(cache).not_to have_received(:store)
        end

        it "cleans up temporary files when SHA1 does not match" do
          begin
            downloader.download(uri, output, expected_sha1: wrong_sha1)
          rescue Factorix::DigestMismatchError
            # Expected exception
          end

          temp_dirs = Dir.glob(File.join(Dir.tmpdir, "factorix*"))
          expect(temp_dirs).to be_empty
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

    context "when download fails with 404" do
      before do
        allow(cache).to receive(:fetch).with(cache_key, output).and_return(false)
        allow(cache).to receive(:with_lock).with(cache_key).and_yield
        allow(client).to receive(:get).and_raise(Factorix::HTTPNotFoundError.new("404 Not Found"))
      end

      it "raises HTTPNotFoundError" do
        expect { downloader.download(uri, output) }.to raise_error(Factorix::HTTPNotFoundError)
      end

      it "cleans up temporary files" do
        begin
          downloader.download(uri, output)
        rescue Factorix::HTTPNotFoundError
          # Expected exception
        end

        temp_dirs = Dir.glob(File.join(Dir.tmpdir, "factorix*"))
        expect(temp_dirs).to be_empty
      end
    end
  end
end
