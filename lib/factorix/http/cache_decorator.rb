# frozen_string_literal: true

require "dry/events"
require "pathname"
require "tempfile"

module Factorix
  module HTTP
    # Adds caching for GET requests
    #
    # Stores successful GET responses in FileSystem cache.
    # Only caches non-streaming requests (no block given).
    class CacheDecorator
      include Factorix::Import[:client, :cache, :logger]
      include Dry::Events::Publisher[:http]

      register_event("cache.hit")
      register_event("cache.miss")

      # Execute an HTTP request (only caches GET without block)
      #
      # @param method [Symbol] HTTP method
      # @param uri [URI::HTTPS] target URI
      # @param headers [Hash<String, String>] request headers
      # @param body [String, IO, nil] request body
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response, Object] response object or parsed data
      def request(method, uri, headers: {}, body: nil, &block)
        if method == :get && !block
          get(uri, headers:)
        else
          client.request(method, uri, headers:, body:, &block)
        end
      end

      # Execute a GET request with caching
      #
      # @param uri [URI::HTTPS] target URI
      # @param headers [Hash<String, String>] request headers
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response, Object] response object or parsed data
      def get(uri, headers: {}, &block)
        # Don't cache streaming requests
        return client.get(uri, headers:, &block) if block

        key = cache.key_for(uri.to_s)

        # Try cache first
        cached_body = cache.read(key)
        if cached_body
          logger.debug("Cache hit", uri: uri.to_s)
          publish("cache.hit", url: uri.to_s)
          return CachedResponse.new(cached_body)
        end

        logger.debug("Cache miss", uri: uri.to_s)
        publish("cache.miss", url: uri.to_s)

        # Fetch with locking (prevents concurrent downloads)
        cache.with_lock(key) do
          # Double-check cache (another thread might have filled it)
          cached_body = cache.read(key)
          if cached_body
            publish("cache.hit", url: uri.to_s)
            return CachedResponse.new(cached_body)
          end

          response = client.get(uri, headers:)

          # Cache successful responses
          if response.success?
            with_temporary_file do |temp|
              temp.write(response.body)
              temp.close
              cache.store(key, temp.path)
            end
          end

          response
        end
      end

      # Execute a POST request (never cached)
      #
      # @param uri [URI::HTTPS] target URI
      # @param body [String, IO] request body
      # @param headers [Hash<String, String>] request headers
      # @param content_type [String, nil] Content-Type header
      # @return [Response] response object
      def post(uri, body:, headers: {}, content_type: nil)
        client.post(uri, body:, headers:, content_type:)
      end

      private def with_temporary_file
        temp_file = Tempfile.new("http_cache")
        yield temp_file
      ensure
        temp_file&.close
        temp_file&.unlink
      end
    end

    # Response wrapper for cached data
    class CachedResponse
      attr_reader :body
      attr_reader :code
      attr_reader :headers

      # @param body [String] cached response body
      def initialize(body)
        @body = body
        @code = 200
        @headers = {"content-type" => ["application/octet-stream"]}
      end

      # Always returns true for cached responses
      #
      # @return [Boolean] true
      def success?
        true
      end

      # Get content length from body size
      #
      # @return [Integer] body size in bytes
      def content_length
        @body.bytesize
      end
    end
  end
end
