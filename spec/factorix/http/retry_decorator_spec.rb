# frozen_string_literal: true

RSpec.describe Factorix::HTTP::RetryDecorator do
  let(:client) { instance_double(Factorix::HTTP::Client) }
  let(:retry_strategy) { instance_double(Factorix::HTTP::RetryStrategy) }
  let(:logger) { instance_double(Dry::Logger::Dispatcher) }
  let(:decorator) { Factorix::HTTP::RetryDecorator.new(client:, retry_strategy:, logger:) }

  let(:uri) { URI("https://example.com/api/endpoint") }
  let(:response) { instance_double(Factorix::HTTP::Response, code: 200, body: "success") }

  describe "#request" do
    before do
      allow(retry_strategy).to receive(:with_retry).and_yield
      allow(client).to receive(:request).and_return(response)
    end

    it "delegates to client with retry" do
      result = decorator.request(:get, uri, headers: {"X-Custom" => "value"})

      expect(retry_strategy).to have_received(:with_retry)
      expect(client).to have_received(:request).with(:get, uri, headers: {"X-Custom" => "value"}, body: nil)
      expect(result).to eq(response)
    end

    it "passes body parameter" do
      decorator.request(:post, uri, body: "test data", headers: {})

      expect(client).to have_received(:request).with(:post, uri, headers: {}, body: "test data")
    end

    it "passes block to client" do
      block = proc {|res| res }
      decorator.request(:get, uri, headers: {}, &block)

      expect(client).to have_received(:request) do |*_args, &passed_block|
        expect(passed_block).to eq(block)
      end
    end

    context "when retry_strategy retries" do
      before do
        allow(retry_strategy).to receive(:with_retry) do |&block|
          block.call # First attempt
          block.call # Retry
          response
        end
      end

      it "calls client.request multiple times" do
        decorator.request(:get, uri, headers: {})

        expect(client).to have_received(:request).twice
      end
    end
  end

  describe "#get" do
    before do
      allow(retry_strategy).to receive(:with_retry).and_yield
      allow(client).to receive(:get).and_return(response)
    end

    it "delegates to client.get with retry" do
      result = decorator.get(uri, headers: {"Authorization" => "Bearer token"})

      expect(retry_strategy).to have_received(:with_retry)
      expect(client).to have_received(:get).with(uri, headers: {"Authorization" => "Bearer token"})
      expect(result).to eq(response)
    end

    it "passes block to client.get" do
      block = proc {|res| res }
      decorator.get(uri, headers: {}, &block)

      expect(client).to have_received(:get) do |*_args, &passed_block|
        expect(passed_block).to eq(block)
      end
    end

    it "defaults headers to empty hash" do
      decorator.get(uri)

      expect(client).to have_received(:get).with(uri, headers: {})
    end
  end

  describe "#post" do
    before do
      allow(retry_strategy).to receive(:with_retry).and_yield
      allow(client).to receive(:post).and_return(response)
    end

    it "delegates to client.post with retry" do
      result = decorator.post(uri, body: "request data", headers: {"X-Custom" => "value"})

      expect(retry_strategy).to have_received(:with_retry)
      expect(client).to have_received(:post).with(
        uri,
        body: "request data",
        headers: {"X-Custom" => "value"},
        content_type: nil
      )
      expect(result).to eq(response)
    end

    it "passes content_type parameter" do
      decorator.post(uri, body: '{"key":"value"}', content_type: "application/json")

      expect(client).to have_received(:post).with(
        uri,
        body: '{"key":"value"}',
        headers: {},
        content_type: "application/json"
      )
    end

    it "defaults headers to empty hash" do
      decorator.post(uri, body: "data")

      expect(client).to have_received(:post).with(
        uri,
        body: "data",
        headers: {},
        content_type: nil
      )
    end
  end
end
