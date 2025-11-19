# frozen_string_literal: true

RSpec.describe Factorix::HTTP::CacheDecorator do
  let(:client) { instance_double(Factorix::HTTP::Client) }
  let(:cache) { instance_double(Factorix::Cache::FileSystem) }
  let(:logger) { instance_double(Dry::Logger::Dispatcher) }
  let(:decorator) { Factorix::HTTP::CacheDecorator.new(client:, cache:, logger:) }

  let(:uri) { URI("https://example.com/api/data.json") }
  let(:cache_key) { "cache_key_123" }
  let(:response) { instance_double(Factorix::HTTP::Response, success?: true, body: "response data") }

  before do
    allow(logger).to receive(:debug)
    allow(cache).to receive(:key_for).with(uri.to_s).and_return(cache_key)
  end

  describe "#request" do
    context "with GET method and no block" do
      it "delegates to #get" do
        allow(cache).to receive(:read).with(cache_key).and_return("cached data")

        result = decorator.request(:get, uri, headers: {"X-Custom" => "value"})

        expect(result).to be_a(Factorix::HTTP::CachedResponse)
        expect(result.body).to eq("cached data")
      end
    end

    context "with GET method and block" do
      it "bypasses cache and delegates to client" do
        allow(cache).to receive(:read)
        allow(client).to receive(:request).and_return(response)
        block = proc {|res| res }

        result = decorator.request(:get, uri, headers: {}, &block)

        expect(cache).not_to have_received(:read)
        expect(client).to have_received(:request).with(:get, uri, headers: {}, body: nil)
        expect(result).to eq(response)
      end
    end

    context "with non-GET method" do
      it "bypasses cache and delegates to client" do
        allow(cache).to receive(:read)
        allow(client).to receive(:request).and_return(response)

        result = decorator.request(:post, uri, headers: {}, body: "data")

        expect(cache).not_to have_received(:read)
        expect(client).to have_received(:request).with(:post, uri, headers: {}, body: "data")
        expect(result).to eq(response)
      end
    end
  end

  describe "#get" do
    context "with block (streaming)" do
      it "bypasses cache and delegates to client.get" do
        allow(cache).to receive(:read)
        allow(client).to receive(:get).and_return(response)
        block = proc {|res| res }

        result = decorator.get(uri, headers: {}, &block)

        expect(cache).not_to have_received(:read)
        expect(client).to have_received(:get).with(uri, headers: {})
        expect(result).to eq(response)
      end
    end

    context "when cache hit" do
      before do
        allow(cache).to receive(:read).with(cache_key).and_return("cached content")
      end

      it "returns cached response" do
        allow(client).to receive(:get)

        result = decorator.get(uri)

        expect(result).to be_a(Factorix::HTTP::CachedResponse)
        expect(result.body).to eq("cached content")
        expect(client).not_to have_received(:get)
      end

      it "logs cache hit" do
        decorator.get(uri)

        expect(logger).to have_received(:debug).with("Cache hit", uri: uri.to_s)
      end

      it "publishes cache.hit event" do
        events = []
        decorator.subscribe("cache.hit") {|event| events << event }

        decorator.get(uri)

        expect(events).to have_attributes(size: 1)
        expect(events.first[:url]).to eq(uri.to_s)
      end
    end

    context "when cache miss" do
      before do
        allow(cache).to receive(:read).with(cache_key).and_return(nil)
        allow(cache).to receive(:with_lock).with(cache_key).and_yield
        allow(cache).to receive(:store)
        allow(client).to receive(:get).and_return(response)
      end

      it "fetches from client" do
        result = decorator.get(uri, headers: {"Authorization" => "Bearer token"})

        expect(client).to have_received(:get).with(uri, headers: {"Authorization" => "Bearer token"})
        expect(result).to eq(response)
      end

      it "logs cache miss" do
        decorator.get(uri)

        expect(logger).to have_received(:debug).with("Cache miss", uri: uri.to_s)
      end

      it "publishes cache.miss event" do
        events = []
        decorator.subscribe("cache.miss") {|event| events << event }

        decorator.get(uri)

        expect(events).to have_attributes(size: 1)
        expect(events.first[:url]).to eq(uri.to_s)
      end

      it "stores successful response in cache" do
        decorator.get(uri)

        expect(cache).to have_received(:store) do |key, path|
          expect(key).to eq(cache_key)
          expect(path).to be_a(String)
          expect(File.exist?(path)).to be false # Temp file should be cleaned up
        end
      end

      it "uses locking to prevent concurrent downloads" do
        decorator.get(uri)

        expect(cache).to have_received(:with_lock).with(cache_key)
      end

      context "when response is not successful" do
        let(:error_response) { instance_double(Factorix::HTTP::Response, success?: false, body: "error") }

        before do
          allow(client).to receive(:get).and_return(error_response)
        end

        it "does not cache the response" do
          decorator.get(uri)

          expect(cache).not_to have_received(:store)
        end

        it "returns the error response" do
          result = decorator.get(uri)

          expect(result).to eq(error_response)
        end
      end

      context "when another thread fills the cache (double-check)" do
        before do
          # First read returns nil (cache miss), second read returns data (filled by another thread)
          allow(cache).to receive(:read).with(cache_key).and_return(nil, "cached by other thread")
        end

        it "returns the cached data without fetching" do
          result = decorator.get(uri)

          expect(result).to be_a(Factorix::HTTP::CachedResponse)
          expect(result.body).to eq("cached by other thread")
          expect(client).not_to have_received(:get)
        end

        it "publishes cache.hit event for double-check hit" do
          events = []
          decorator.subscribe("cache.hit") {|event| events << event }

          decorator.get(uri)

          expect(events).to have_attributes(size: 1)
        end
      end
    end
  end

  describe "#post" do
    it "delegates to client.post without caching" do
      allow(cache).to receive(:read)
      allow(cache).to receive(:store)
      allow(client).to receive(:post).and_return(response)

      result = decorator.post(uri, body: "data", headers: {"X-Custom" => "value"}, content_type: "application/json")

      expect(cache).not_to have_received(:read)
      expect(cache).not_to have_received(:store)
      expect(client).to have_received(:post).with(
        uri,
        body: "data",
        headers: {"X-Custom" => "value"},
        content_type: "application/json"
      )
      expect(result).to eq(response)
    end
  end
end
