# frozen_string_literal: true

require "pathname"
require "tmpdir"
require_relative "../../lib/factorix/http_client"
require_relative "../../lib/factorix/progress/bar"
require_relative "../../lib/factorix/retry_strategy"

RSpec.describe Factorix::HttpClient do
  let(:retry_strategy) { instance_double(Factorix::RetryStrategy) }
  let(:progress) { instance_double(Factorix::Progress::Bar) }
  let(:uri) { URI("https://example.com/file.zip") }
  let(:http_client) { Factorix::HttpClient.new(retry_strategy:, progress:) }
  let(:output_dir) { Pathname(Dir.mktmpdir("output")) }
  let(:output) { output_dir.join("file.zip") }

  before do
    allow(progress).to receive_messages(
      content_length_proc: proc {|size| size },
      progress_proc: proc {|size| size }
    )
    allow(uri).to receive(:open).and_return(nil)
  end

  after do
    FileUtils.remove_entry(output_dir)
  end

  describe "#download" do
    before do
      allow(retry_strategy).to receive(:with_retry).and_yield
    end

    context "when downloading a file" do
      before do
        allow(uri).to receive(:open).and_yield(StringIO.new("downloaded content"))
      end

      it "downloads the file" do
        http_client.download(uri, output)
        expect(output.read).to eq("downloaded content")
      end

      it "uses the retry strategy" do
        http_client.download(uri, output)
        expect(retry_strategy).to have_received(:with_retry)
      end

      it "uses the progress callbacks" do
        http_client.download(uri, output)
        # Verify that progress callbacks are properly configured
        expect(uri).to have_received(:open).with(
          "rb",
          hash_including(
            content_length_proc: progress.content_length_proc,
            progress_proc: progress.progress_proc
          )
        )
      end

      context "without progress tracking" do
        let(:http_client) { Factorix::HttpClient.new(retry_strategy:) }

        it "downloads without progress callbacks" do
          http_client.download(uri, output)
          expect(uri).to have_received(:open).with(
            "rb",
            hash_excluding(:content_length_proc, :progress_proc)
          )
        end
      end
    end

    context "when resuming a download" do
      before do
        output.binwrite("partial ")
        allow(uri).to receive(:open).and_yield(StringIO.new("content"))
      end

      it "resumes the download" do
        http_client.download(uri, output)
        expect(output.read).to eq("partial content")
      end

      it "uses the Range header" do
        http_client.download(uri, output)
        expect(uri).to have_received(:open).with(
          "rb",
          hash_including("Range" => "bytes=8-")
        )
      end

      context "when the server does not support range requests" do
        before do
          allow(uri).to receive(:open)
            .with("rb", hash_including("Range" => "bytes=8-"))
            .and_raise(OpenURI::HTTPError.new("416 Range Not Satisfiable", nil))
            .once
          allow(uri).to receive(:open)
            .with("rb", hash_excluding("Range"))
            .and_yield(StringIO.new("new content"))
            .once
        end

        it "falls back to full download" do
          http_client.download(uri, output)
          expect(output.read).to eq("new content")
        end
      end

      context "when the server returns other HTTP errors" do
        before do
          allow(uri).to receive(:open)
            .with("rb", hash_including("Range" => "bytes=8-"))
            .and_raise(OpenURI::HTTPError.new("403 Forbidden", nil))
        end

        it "raises DownloadError without retrying" do
          expect { http_client.download(uri, output) }.to raise_error(Factorix::DownloadError, "Download failed: 403 Forbidden")
          expect(uri).to have_received(:open).once
        end
      end
    end

    context "with invalid URI" do
      it "raises ArgumentError for non-HTTP URI" do
        expect { http_client.download(Object.new, output) }.to raise_error(ArgumentError, "URL must be HTTP or HTTPS")
      end
    end

    context "when download fails" do
      before do
        allow(uri).to receive(:open)
          .and_raise(OpenURI::HTTPError.new("404 Not Found", nil))
      end

      it "raises DownloadError" do
        expect { http_client.download(uri, output) }.to raise_error(Factorix::DownloadError, "Download failed: 404 Not Found")
      end
    end
  end
end
