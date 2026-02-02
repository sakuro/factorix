# frozen_string_literal: true

module Factorix
  module HTTP
    # Response wrapper for cached data
    #
    # Provides a simple response object that can be constructed from
    # a cached body string, without requiring an actual HTTP response.
    # Used by CacheDecorator to return cached content with a uniform
    # interface matching Response objects.
    class CachedResponse
      attr_reader :body
      attr_reader :code
      attr_reader :headers
      attr_reader :uri

      # @param body [String] cached response body
      # @param uri [URI, nil] original request URI (not stored in cache, always nil)
      def initialize(body, uri: nil)
        @body = body
        @code = 200
        @headers = {"content-type" => ["application/octet-stream"]}
        @uri = uri
      end

      # Always returns true for cached responses
      #
      # Since only successful responses are cached, all CachedResponse
      # objects represent successful HTTP interactions.
      #
      # @return [Boolean] true
      def success? = true

      # Get content length from body size
      #
      # @return [Integer] body size in bytes
      def content_length = @body.bytesize
    end
  end
end
