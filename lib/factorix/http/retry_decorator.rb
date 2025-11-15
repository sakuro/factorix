# frozen_string_literal: true

module Factorix
  module HTTP
    # Adds automatic retry with exponential backoff to HTTP client
    #
    # Wraps any HTTP client and retries requests on network errors
    # using the configured RetryStrategy.
    class RetryDecorator
      include Factorix::Import["retry_strategy", "logger"]

      # @param client [#request, #get, #post] HTTP client to wrap
      # @param retry_strategy [RetryStrategy, nil] custom retry strategy
      # @param logger [Dry::Logger::Dispatcher, nil] logger instance
      def initialize(client, retry_strategy: nil, logger: nil)
        super(retry_strategy:, logger:)
        @client = client
      end

      # Execute an HTTP request with retry
      #
      # @param method [Symbol] HTTP method
      # @param uri [URI::HTTPS] target URI
      # @param options [Hash] request options
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response] response object
      def request(method, uri, **options, &block)
        retry_strategy.with_retry do
          @client.request(method, uri, **options, &block)
        end
      end

      # Execute a GET request with retry
      #
      # @param uri [URI::HTTPS] target URI
      # @param options [Hash] request options
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response] response object
      def get(uri, **options, &block)
        retry_strategy.with_retry do
          @client.get(uri, **options, &block)
        end
      end

      # Execute a POST request with retry
      #
      # @param uri [URI::HTTPS] target URI
      # @param options [Hash] request options
      # @return [Response] response object
      def post(uri, **options)
        retry_strategy.with_retry do
          @client.post(uri, **options)
        end
      end
    end
  end
end
