# frozen_string_literal: true

require "dry/events"
require "tempfile"
require "pathname"

module Factorix
  module HTTP
    # Adds caching for GET requests
    #
    # Stores successful GET responses in FileSystem cache.
    # Only caches non-streaming requests (no block given).
    class CacheDecorator
      include Factorix::Import["logger"]
      include Dry::Events::Publisher[:http]

      register_event("cache.hit")
      register_event("cache.miss")

      # @param client [#request, #get, #post] HTTP client to wrap
      # @param cache [Cache::FileSystem] cache instance
      # @param logger [Dry::Logger::Dispatcher, nil] logger instance
      def initialize(client, cache:, logger: nil)
        super(logger:)
        @client = client
        @cache = cache
      end

      # Execute an HTTP request (only caches GET without block)
      #
      # @param method [Symbol] HTTP method
      # @param uri [URI::HTTPS] target URI
      # @param options [Hash] request options
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response, Object] response object or parsed data
      def request(method, uri, **options, &block)
        if method == :get && !block
          get(uri, **options)
        else
          @client.request(method, uri, **options, &block)
        end
      end

      # Execute a GET request with caching
      #
      # @param uri [URI::HTTPS] target URI
      # @param options [Hash] request options
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response, Object] response object or parsed data
      def get(uri, **options, &block)
        # Don't cache streaming requests
        return @client.get(uri, **options, &block) if block

        key = @cache.key_for(uri.to_s)

        # Try cache first
        cached_body = @cache.read(key)
        if cached_body
          logger.debug("Cache hit", uri: uri.to_s)
          publish("cache.hit", url: uri.to_s)
          return CachedResponse.new(cached_body)
        end

        logger.debug("Cache miss", uri: uri.to_s)
        publish("cache.miss", url: uri.to_s)

        # Fetch with locking (prevents concurrent downloads)
        @cache.with_lock(key) do
          # Double-check cache (another thread might have filled it)
          cached_body = @cache.read(key)
          if cached_body
            publish("cache.hit", url: uri.to_s)
            return CachedResponse.new(cached_body)
          end

          response = @client.get(uri, **options)

          # Cache successful responses
          if response.success?
            with_temporary_file do |temp|
              temp.write(response.body)
              temp.close
              @cache.store(key, temp.path)
            end
          end

          response
        end
      end

      # Execute a POST request (never cached)
      #
      # @param uri [URI::HTTPS] target URI
      # @param options [Hash] request options
      # @return [Response] response object
      def post(uri, **options)
        @client.post(uri, **options)
      end

      private

      def with_temporary_file
        temp_file = Tempfile.new("http_cache")
        yield temp_file
      ensure
        temp_file&.close
        temp_file&.unlink
      end
    end

    # Response wrapper for cached data
    class CachedResponse
      attr_reader :body, :code, :headers

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
