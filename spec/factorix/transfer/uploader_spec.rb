# frozen_string_literal: true

require "dry/monads"
require "tmpdir"

RSpec.describe Factorix::Transfer::Uploader do
  include Dry::Monads[:result]

  let(:http) { instance_double(Factorix::Transfer::HTTP) }
  let(:uploader) { Factorix::Transfer::Uploader.new(http:) }
  let(:url) { URI("https://example.com/upload") }
  let(:tmpdir) { Pathname(Dir.mktmpdir) }
  let(:file_path) { tmpdir / "upload.zip" }

  before do
    file_path.write("test file content")
  end

  after do
    tmpdir.rmtree if tmpdir.exist?
  end

  describe "#upload" do
    context "with successful upload" do
      before do
        allow(http).to receive(:upload).and_return(Success(:ok))
      end

      it "uploads a file" do
        uploader.upload(url, file_path)
        expect(http).to have_received(:upload).with(url, file_path, field_name: "file")
      end

      it "accepts String URL" do
        uploader.upload(url.to_s, file_path)
        expect(http).to have_received(:upload).with(url, file_path, field_name: "file")
      end

      it "accepts custom field name" do
        uploader.upload(url, file_path, field_name: "mod_file")
        expect(http).to have_received(:upload).with(url, file_path, field_name: "mod_file")
      end
    end

    context "with HTTP errors" do
      it "raises HTTPClientError for 4xx errors" do
        allow(http).to receive(:upload).and_return(Failure(Factorix::HTTPClientError.new("400 Bad Request")))

        expect {
          uploader.upload(url, file_path)
        }.to raise_error(Factorix::HTTPClientError, /400/)
      end

      it "raises HTTPServerError for 5xx errors" do
        allow(http).to receive(:upload).and_return(Failure(Factorix::HTTPServerError.new("500 Internal Server Error")))

        expect {
          uploader.upload(url, file_path)
        }.to raise_error(Factorix::HTTPServerError, /500/)
      end
    end

    context "with invalid URL" do
      it "raises ArgumentError for HTTP URL" do
        http_url = "http://example.com/upload"

        expect {
          uploader.upload(http_url, file_path)
        }.to raise_error(ArgumentError, /must be HTTPS/)
      end
    end
  end
end
