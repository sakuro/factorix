# frozen_string_literal: true

require "tmpdir"

RSpec.describe Factorix::Transfer::Uploader do
  let(:client) { instance_double(Factorix::HTTP::Client) }
  let(:uploader) { Factorix::Transfer::Uploader.new(client:) }
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
        response = instance_double(Factorix::HTTP::Response, code: 200)
        allow(client).to receive(:post).and_return(response)
      end

      it "uploads a file" do
        uploader.upload(url, file_path)
        expect(client).to have_received(:post) do |uri, **options|
          expect(uri).to eq(url)
          expect(options[:content_type]).to match(%r{multipart/form-data})
        end
      end

      it "accepts String URL" do
        uploader.upload(url.to_s, file_path)
        expect(client).to have_received(:post)
      end

      it "accepts custom field name" do
        uploader.upload(url, file_path, field_name: "mod_file")
        expect(client).to have_received(:post)
      end

      it "accepts additional form fields" do
        uploader.upload(url, file_path, fields: {description: "Test description", category: "content"})
        expect(client).to have_received(:post) do |_uri, **options|
          body = options[:body]
          # Read the body stream to verify it contains the metadata
          content = body.read
          body.rewind
          expect(content).to include('name="description"')
          expect(content).to include("Test description")
          expect(content).to include('name="category"')
          expect(content).to include("content")
        end
      end
    end

    context "with HTTP errors" do
      it "raises HTTPClientError for 4xx errors" do
        allow(client).to receive(:post).and_raise(Factorix::HTTPClientError.new("400 Bad Request"))

        expect {
          uploader.upload(url, file_path)
        }.to raise_error(Factorix::HTTPClientError, /400/)
      end

      it "raises HTTPServerError for 5xx errors" do
        allow(client).to receive(:post).and_raise(Factorix::HTTPServerError.new("500 Internal Server Error"))

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
