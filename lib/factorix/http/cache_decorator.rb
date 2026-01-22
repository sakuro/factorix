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
      # @!parse
      #   # @return [HTTP::Client]
      #   attr_reader :client
      #   # @return [Cache::FileSystem]
      #   attr_reader :cache
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      include Import[:client, :cache, :logger]
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

        cache_key = uri.to_s

        cached_body = cache.read(cache_key)
        if cached_body
          logger.debug("Cache hit", uri: uri.to_s)
          publish("cache.hit", url: uri.to_s)
          return CachedResponse.new(cached_body)
        end

        logger.debug("Cache miss", uri: uri.to_s)
        publish("cache.miss", url: uri.to_s)

        # Locking prevents concurrent downloads of the same resource
        cache.with_lock(cache_key) do
          # Double-check: another thread might have filled the cache
          cached_body = cache.read(cache_key)
          if cached_body
            publish("cache.hit", url: uri.to_s)
            return CachedResponse.new(cached_body)
          end

          response = client.get(uri, headers:)

          if response.success?
            with_temporary_file do |temp|
              temp.write(response.body)
              temp.close
              cache.store(cache_key, Pathname(temp.path))
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
      def post(uri, body:, headers: {}, content_type: nil) = client.post(uri, body:, headers:, content_type:)

      private def with_temporary_file
        temp_file = Tempfile.new("http_cache")
        yield temp_file
      ensure
        temp_file&.close
        temp_file&.unlink
      end
    end
  end
end
