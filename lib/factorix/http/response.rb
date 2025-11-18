# frozen_string_literal: true

module Factorix
  module HTTP
    # Simple response wrapper for Net::HTTP responses
    class Response
      attr_reader :code
      attr_reader :body
      attr_reader :headers
      attr_reader :raw_response

      # @param net_http_response [Net::HTTPResponse] Raw Net::HTTP response
      def initialize(net_http_response)
        @code = Integer(net_http_response.code, 10)
        @body = net_http_response.body
        @headers = net_http_response.to_hash
        @raw_response = net_http_response
      end

      # Check if response is successful (2xx)
      #
      # @return [Boolean] true if 2xx response
      def success? = (200..299).cover?(@code)

      # Get Content-Length from headers
      #
      # @return [Integer, nil] content length in bytes, or nil if not present
      def content_length = Integer(@headers["content-length"]&.first, 10)
    end
  end
end
