# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"

module Factorix
  module HTTP
    # Low-level HTTP client using Net::HTTP
    #
    # Responsibilities:
    # - Create and configure Net::HTTP instances
    # - Execute HTTP methods (GET, POST)
    # - Handle redirects (up to MAX_REDIRECTS)
    # - Parse response codes and raise appropriate errors
    # - Stream reading/writing for large files
    #
    # Does NOT handle:
    # - Retry logic (delegated to RetryDecorator)
    # - Progress events (delegated to EventDecorator)
    # - Caching (delegated to CacheDecorator)
    # - JSON parsing (handled by API clients)
    class Client
      include Import[:logger]

      MAX_REDIRECTS = 10
      private_constant :MAX_REDIRECTS

      # Execute an HTTP request
      #
      # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
      # @param uri [URI::HTTPS] target URI
      # @param headers [Hash<String, String>] request headers
      # @param body [String, IO, nil] request body
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response] response object
      def request(method, uri, headers: {}, body: nil, &)
        raise ArgumentError, "URL must be HTTPS" unless uri.is_a?(URI::HTTPS)

        perform_request(method, uri, redirect_count: 0, headers:, body:, &)
      end

      # Execute a GET request
      #
      # @param uri [URI::HTTPS] target URI
      # @param headers [Hash<String, String>] request headers
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response] response object
      def get(uri, headers: {}, &) = request(:get, uri, headers:, &)

      # Execute a POST request
      #
      # @param uri [URI::HTTPS] target URI
      # @param body [String, IO] request body
      # @param headers [Hash<String, String>] request headers
      # @param content_type [String, nil] Content-Type header
      # @return [Response] response object
      def post(uri, body:, headers: {}, content_type: nil)
        headers = headers.merge("Content-Type" => content_type) if content_type
        request(:post, uri, body:, headers:)
      end

      private def perform_request(method, uri, redirect_count:, headers:, body:, &block)
        if redirect_count > MAX_REDIRECTS
          logger.error("Too many redirects", redirect_count:)
          raise ArgumentError, "Too many redirects (#{redirect_count})"
        end

        http = create_http(uri)
        req = build_request(method, uri, headers:, body:)

        result = nil
        http.request(req) do |response|
          result = handle_response(response, method, uri, redirect_count, &block)
        end
        result
      end

      private def handle_response(response, _method, _uri, redirect_count, &block)
        case response
        when Net::HTTPSuccess, Net::HTTPPartialContent
          yield(response) if block
          Response.new(response)

        when Net::HTTPRedirection
          location = response["Location"]
          redirect_url = URI(location)
          logger.info("Following redirect", location: redirect_url.to_s)

          # Follow redirect (always as GET)
          perform_request(:get, redirect_url, redirect_count: redirect_count + 1, headers: {}, body: nil, &block)

        when Net::HTTPClientError
          logger.error("HTTP client error", code: response.code, message: response.message)
          raise HTTPClientError, "#{response.code} #{response.message}"

        when Net::HTTPServerError
          logger.error("HTTP server error", code: response.code, message: response.message)
          raise HTTPServerError, "#{response.code} #{response.message}"

        else
          raise HTTPError, "#{response.code} #{response.message}"
        end
      rescue URI::InvalidURIError
        raise HTTPError, "Invalid redirect URI: #{response["Location"]}"
      end

      private def build_request(method, uri, headers:, body:)
        request = case method
                  when :get then Net::HTTP::Get.new(uri)
                  when :post then Net::HTTP::Post.new(uri)
                  when :put then Net::HTTP::Put.new(uri)
                  when :delete then Net::HTTP::Delete.new(uri)
                  else raise ArgumentError, "Unsupported method: #{method}"
                  end

        headers.each {|k, v| request[k] = v }

        if body
          if body.respond_to?(:read)
            request.body_stream = body
          else
            request.body = body
          end
        end

        request
      end

      private def create_http(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.open_timeout = Application.config.http.connect_timeout
        http.read_timeout = Application.config.http.read_timeout
        http.write_timeout = Application.config.http.write_timeout if http.respond_to?(:write_timeout=)
        http
      end
    end
  end
end
