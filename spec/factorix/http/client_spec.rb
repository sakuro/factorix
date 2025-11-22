# frozen_string_literal: true

require "net/http"
require "webmock/rspec"

RSpec.describe Factorix::HTTP::Client do
  let(:client) { Factorix::HTTP::Client.new }
  let(:uri) { URI("https://example.com/api/endpoint") }

  before do
    # Configure stub application config
    allow(Factorix::Application.config.http).to receive_messages(
      connect_timeout: 10,
      read_timeout: 30,
      write_timeout: 30
    )
  end

  describe "#get" do
    context "with successful response" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(status: 200, body: "success", headers: {})
      end

      it "returns a successful response" do
        response = client.get(uri)
        expect(response).to be_a(Factorix::HTTP::Response)
        expect(response.body).to eq("success")
      end
    end

    context "with custom headers" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .with(headers: {"Authorization" => "Bearer token123"})
          .to_return(status: 200, body: "authenticated")
      end

      it "includes the custom headers" do
        response = client.get(uri, headers: {"Authorization" => "Bearer token123"})
        expect(response.body).to eq("authenticated")
      end
    end

    context "with streaming block" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(status: 200, body: "streamed content")
      end

      it "yields the response to the block" do
        yielded_response = nil
        response = client.get(uri) {|res| yielded_response = res }

        expect(yielded_response).to be_a(Net::HTTPSuccess)
        expect(response).to be_a(Factorix::HTTP::Response)
      end
    end
  end

  describe "#post" do
    context "with string body" do
      before do
        stub_request(:post, "https://example.com/api/endpoint")
          .with(body: "request data")
          .to_return(status: 201, body: "created")
      end

      it "sends the POST request with body" do
        response = client.post(uri, body: "request data")
        expect(response.body).to eq("created")
      end
    end

    context "with content type" do
      before do
        stub_request(:post, "https://example.com/api/endpoint")
          .with(
            body: '{"key":"value"}',
            headers: {"Content-Type" => "application/json"}
          )
          .to_return(status: 201, body: "created")
      end

      it "includes the Content-Type header" do
        response = client.post(
          uri,
          body: '{"key":"value"}',
          content_type: "application/json"
        )
        expect(response.body).to eq("created")
      end
    end

    context "with IO body" do
      let(:io_body) { StringIO.new("stream data") }

      before do
        stub_request(:post, "https://example.com/api/endpoint")
          .with(body: "stream data")
          .to_return(status: 201, body: "created")
      end

      it "sends the POST request with body stream" do
        response = client.post(uri, body: io_body)
        expect(response.body).to eq("created")
      end
    end
  end

  describe "#request" do
    context "with non-HTTPS URI" do
      let(:http_uri) { URI("http://example.com/api") }

      it "raises ArgumentError" do
        expect {
          client.request(:get, http_uri)
        }.to raise_error(ArgumentError, "URL must be HTTPS")
      end
    end

    context "with PUT method" do
      before do
        stub_request(:put, "https://example.com/api/endpoint")
          .with(body: "update data")
          .to_return(status: 200, body: "updated")
      end

      it "sends PUT request" do
        response = client.request(:put, uri, body: "update data")
        expect(response.body).to eq("updated")
      end
    end

    context "with DELETE method" do
      before do
        stub_request(:delete, "https://example.com/api/endpoint")
          .to_return(status: 204, body: "")
      end

      it "sends DELETE request" do
        response = client.request(:delete, uri)
        expect(response.code).to eq(204)
      end
    end

    context "with unsupported method" do
      it "raises ArgumentError" do
        expect {
          client.__send__(:build_request, :patch, uri, headers: {}, body: nil)
        }.to raise_error(ArgumentError, "Unsupported method: patch")
      end
    end
  end

  describe "redirect handling" do
    context "with single redirect" do
      before do
        stub_request(:get, "https://example.com/original")
          .to_return(status: 302, headers: {"Location" => "https://example.com/redirected"})

        stub_request(:get, "https://example.com/redirected")
          .to_return(status: 200, body: "final content")
      end

      it "follows the redirect" do
        response = client.get(URI("https://example.com/original"))
        expect(response.body).to eq("final content")
      end
    end

    context "with multiple redirects" do
      before do
        stub_request(:get, "https://example.com/step1")
          .to_return(status: 301, headers: {"Location" => "https://example.com/step2"})

        stub_request(:get, "https://example.com/step2")
          .to_return(status: 302, headers: {"Location" => "https://example.com/step3"})

        stub_request(:get, "https://example.com/step3")
          .to_return(status: 200, body: "final destination")
      end

      it "follows multiple redirects" do
        response = client.get(URI("https://example.com/step1"))
        expect(response.body).to eq("final destination")
      end
    end

    context "with too many redirects" do
      before do
        # Create a redirect loop
        (0..11).each do |i|
          stub_request(:get, "https://example.com/redirect#{i}")
            .to_return(status: 302, headers: {"Location" => "https://example.com/redirect#{i + 1}"})
        end
      end

      it "raises ArgumentError after max redirects" do
        expect {
          client.get(URI("https://example.com/redirect0"))
        }.to raise_error(ArgumentError, /Too many redirects/)
      end
    end

    context "with invalid redirect URI" do
      before do
        stub_request(:get, "https://example.com/original")
          .to_return(status: 302, headers: {"Location" => "ht!tp://invalid uri"})
      end

      it "raises HTTPError for invalid redirect URI" do
        expect {
          client.get(URI("https://example.com/original"))
        }.to raise_error(Factorix::HTTPError, /Invalid redirect URI/)
      end
    end
  end

  describe "error handling" do
    context "with 404 not found error" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(status: [404, "Not Found"], body: "Not Found")
      end

      it "raises HTTPNotFoundError" do
        expect {
          client.get(uri)
        }.to raise_error(Factorix::HTTPNotFoundError, "404 Not Found")
      end
    end

    context "with 400 bad request error" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(status: [400, "Bad Request"], body: "Bad Request")
      end

      it "raises HTTPClientError" do
        expect {
          client.get(uri)
        }.to raise_error(Factorix::HTTPClientError, "400 Bad Request")
      end
    end

    context "with 500 server error" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(status: [500, "Internal Server Error"], body: "Internal Server Error")
      end

      it "raises HTTPServerError" do
        expect {
          client.get(uri)
        }.to raise_error(Factorix::HTTPServerError, "500 Internal Server Error")
      end
    end

    context "with 503 service unavailable" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(status: [503, "Service Unavailable"], body: "Service Unavailable")
      end

      it "raises HTTPServerError" do
        expect {
          client.get(uri)
        }.to raise_error(Factorix::HTTPServerError, "503 Service Unavailable")
      end
    end

    context "with JSON error response containing message" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(
            status: [404, "Not Found"],
            body: '{"message": "Mod not found"}',
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "parses api_message from JSON response" do
        expect {
          client.get(uri)
        }.to raise_error(Factorix::HTTPNotFoundError) do |error|
          expect(error.api_message).to eq("Mod not found")
          expect(error.api_error).to be_nil
        end
      end
    end

    context "with JSON error response containing error and message" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(
            status: [400, "Bad Request"],
            body: '{"error": "InvalidApiKey", "message": "Missing or invalid API key"}',
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "parses both api_error and api_message from JSON response" do
        expect {
          client.get(uri)
        }.to raise_error(Factorix::HTTPClientError) do |error|
          expect(error.api_error).to eq("InvalidApiKey")
          expect(error.api_message).to eq("Missing or invalid API key")
        end
      end
    end

    context "with non-JSON error response" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(
            status: [404, "Not Found"],
            body: "<html>Not Found</html>",
            headers: {"Content-Type" => "text/html"}
          )
      end

      it "does not set api_error or api_message" do
        expect {
          client.get(uri)
        }.to raise_error(Factorix::HTTPNotFoundError) do |error|
          expect(error.api_error).to be_nil
          expect(error.api_message).to be_nil
        end
      end
    end

    context "with invalid JSON error response" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(
            status: [400, "Bad Request"],
            body: "not valid json",
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "does not set api_error or api_message" do
        expect {
          client.get(uri)
        }.to raise_error(Factorix::HTTPClientError) do |error|
          expect(error.api_error).to be_nil
          expect(error.api_message).to be_nil
        end
      end
    end
  end

  describe "partial content support" do
    context "with 206 Partial Content response" do
      before do
        stub_request(:get, "https://example.com/api/endpoint")
          .to_return(status: 206, body: "partial data")
      end

      it "returns a successful response" do
        response = client.get(uri)
        expect(response.body).to eq("partial data")
      end
    end
  end

  describe "HTTP configuration" do
    it "configures SSL verification" do
      http = client.__send__(:create_http, uri)
      expect(http).to be_use_ssl
      expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
    end

    it "configures timeouts from application config" do
      http = client.__send__(:create_http, uri)
      expect(http.open_timeout).to eq(10)
      expect(http.read_timeout).to eq(30)
      expect(http.write_timeout).to eq(30) if http.respond_to?(:write_timeout)
    end
  end
end
