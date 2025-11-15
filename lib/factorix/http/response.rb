# frozen_string_literal: true

module Factorix
  module HTTP
    # Simple response wrapper for Net::HTTP responses
    class Response
      attr_reader :code, :body, :headers, :raw_response

      # @param net_http_response [Net::HTTPResponse] Raw Net::HTTP response
      def initialize(net_http_response)
        @code = net_http_response.code.to_i
        @body = net_http_response.body
        @headers = net_http_response.to_hash
        @raw_response = net_http_response
      end

      # Check if response is successful (2xx)
      #
      # @return [Boolean] true if 2xx response
      def success?
        (200..299).include?(@code)
      end

      # Get Content-Length from headers
      #
      # @return [Integer, nil] content length in bytes, or nil if not present
      def content_length
        @headers["content-length"]&.first&.to_i
      end
    end
  end
end
