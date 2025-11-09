# frozen_string_literal: true

require "tmpdir"

RSpec.describe Factorix::Transfer::HTTP, warn: :silence do
  let(:retry_strategy) { Factorix::Transfer::RetryStrategy.new }
  let(:http_client) { Factorix::Transfer::HTTP.new(retry_strategy:) }
  let(:url) { URI("https://example.com/file.zip") }
  let(:tmpdir) { Pathname(Dir.mktmpdir) }
  let(:output) { tmpdir / "file.zip" }

  after do
    tmpdir.rmtree if tmpdir.exist?
  end

  describe "#download" do
    context "with successful download" do
      it "downloads a file" do
        stub_request(:get, url)
          .to_return(
            status: 200,
            body: "file content",
            headers: {"Content-Length" => "12"}
          )

        http_client.download(url, output)

        expect(output).to exist
        expect(output.read).to eq("file content")
      end

      it "publishes download events" do
        stub_request(:get, url)
          .to_return(
            status: 200,
            body: "file content",
            headers: {"Content-Length" => "12"}
          )

        events = []
        listener = Object.new
        listener.define_singleton_method(:on_download_started) {|event| events << {id: "download.started", payload: event.payload} }
        listener.define_singleton_method(:on_download_progress) {|event| events << {id: "download.progress", payload: event.payload} }
        listener.define_singleton_method(:on_download_completed) {|event| events << {id: "download.completed", payload: event.payload} }

        http_client.subscribe(listener)
        http_client.download(url, output)

        expect(events.size).to eq(3)
        expect(events[0][:id]).to eq("download.started")
        expect(events[0][:payload][:total_size]).to eq(12)
        expect(events[1][:id]).to eq("download.progress")
        expect(events[2][:id]).to eq("download.completed")
      end

      it "handles missing Content-Length header" do
        stub_request(:get, url)
          .to_return(
            status: 200,
            body: "file content"
          )

        events = []
        listener = Object.new
        listener.define_singleton_method(:on_download_started) {|event| events << {id: "download.started", payload: event.payload} }
        listener.define_singleton_method(:on_download_progress) {|event| events << {id: "download.progress", payload: event.payload} }
        listener.define_singleton_method(:on_download_completed) {|event| events << {id: "download.completed", payload: event.payload} }

        http_client.subscribe(listener)
        http_client.download(url, output)

        expect(output).to exist
        expect(events[0][:payload][:total_size]).to be_nil
      end
    end

    context "with resume support" do
      it "resumes partial download" do
        # Create a partial file
        output.write("partial")

        stub_request(:get, url)
          .with(headers: {"Range" => "bytes=7-"})
          .to_return(
            status: 206,
            body: " content",
            headers: {"Content-Length" => "8"}
          )

        http_client.download(url, output)

        expect(output.read).to eq("partial content")
      end

      it "falls back to full download on 416 Range Not Satisfiable" do
        # Create a partial file
        output.write("partial")

        # First request with Range header returns 416
        stub_request(:get, url)
          .with(headers: {"Range" => "bytes=7-"})
          .to_return(status: 416, body: "Range Not Satisfiable")

        # Second request without Range header (full download)
        stub_request(:get, url)
          .with {|request| !request.headers.key?("Range") }
          .to_return(
            status: 200,
            body: "new content",
            headers: {"Content-Length" => "11"}
          )

        http_client.download(url, output)

        expect(output.read).to eq("new content")
      end
    end

    context "with HTTP errors" do
      it "raises HTTPClientError for 4xx errors" do
        stub_request(:get, url).to_return(status: 404, body: "Not Found")

        expect {
          http_client.download(url, output)
        }.to raise_error(Factorix::HTTPClientError, /404/)
      end

      it "raises HTTPServerError for 5xx errors" do
        stub_request(:get, url).to_return(status: 500, body: "Internal Server Error")

        expect {
          http_client.download(url, output)
        }.to raise_error(Factorix::HTTPServerError, /500/)
      end
    end

    context "with invalid URL" do
      it "raises ArgumentError for HTTP URL" do
        http_url = URI("http://example.com/file.zip")

        expect {
          http_client.download(http_url, output)
        }.to raise_error(ArgumentError, /must be HTTPS/)
      end

      it "raises ArgumentError for FTP URL" do
        ftp_url = URI("ftp://example.com/file.zip")

        expect {
          http_client.download(ftp_url, output)
        }.to raise_error(ArgumentError, /must be HTTPS/)
      end
    end

    context "with retry on network errors" do
      it "retries on connection errors" do
        stub_request(:get, url)
          .to_raise(Errno::ECONNRESET).then
          .to_return(
            status: 200,
            body: "file content",
            headers: {"Content-Length" => "12"}
          )

        http_client.download(url, output)

        expect(output).to exist
        expect(output.read).to eq("file content")
      end
    end
  end
end
