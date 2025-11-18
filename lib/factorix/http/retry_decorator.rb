# frozen_string_literal: true

module Factorix
  module HTTP
    # Adds automatic retry with exponential backoff to HTTP client
    #
    # Wraps any HTTP client and retries requests on network errors
    # using the configured RetryStrategy.
    class RetryDecorator
      # @!parse
      #   # @return [HTTP::Client]
      #   attr_reader :client
      #   # @return [HTTP::RetryStrategy]
      #   attr_reader :retry_strategy
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      include Factorix::Import[:client, :retry_strategy, :logger]

      # Execute an HTTP request with retry
      #
      # @param method [Symbol] HTTP method
      # @param uri [URI::HTTPS] target URI
      # @param headers [Hash<String, String>] request headers
      # @param body [String, IO, nil] request body
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response] response object
      def request(method, uri, headers: {}, body: nil, &block)
        retry_strategy.with_retry do
          client.request(method, uri, headers:, body:, &block)
        end
      end

      # Execute a GET request with retry
      #
      # @param uri [URI::HTTPS] target URI
      # @param headers [Hash<String, String>] request headers
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response] response object
      def get(uri, headers: {}, &block)
        retry_strategy.with_retry do
          client.get(uri, headers:, &block)
        end
      end

      # Execute a POST request with retry
      #
      # @param uri [URI::HTTPS] target URI
      # @param body [String, IO] request body
      # @param headers [Hash<String, String>] request headers
      # @param content_type [String, nil] Content-Type header
      # @return [Response] response object
      def post(uri, body:, headers: {}, content_type: nil)
        retry_strategy.with_retry do
          client.post(uri, body:, headers:, content_type:)
        end
      end
    end
  end
end
