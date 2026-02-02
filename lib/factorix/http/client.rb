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
    class Client
      include Import[:logger]

      MAX_REDIRECTS = 10
      private_constant :MAX_REDIRECTS

      # @return [Array<String>] URL parameter names to mask in logs
      attr_reader :masked_params

      # @param masked_params [Array<String>] URL parameter names to mask in logs
      def initialize(masked_params: [], **)
        super(**)
        @masked_params = masked_params.freeze
      end

      # Execute an HTTP request
      #
      # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
      # @param uri [URI::HTTPS] target URI
      # @param headers [Hash<String, String>] request headers
      # @param body [String, IO, nil] request body
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response] response object
      # @raise [URLError] if URI is not HTTPS or too many redirects
      # @raise [InvalidArgumentError] if HTTP method is unsupported
      # @raise [HTTPNotFoundError] for 404 errors
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      # @raise [HTTPError] for other HTTP errors
      def request(method, uri, headers: {}, body: nil, &)
        raise URLError, "URL must be HTTPS" unless uri.is_a?(URI::HTTPS)

        logger.info("HTTP request", method: method.upcase, url: mask_credentials(uri))
        perform_request(method, uri, redirect_count: 0, headers:, body:, &)
      end

      # Execute a GET request
      #
      # @param uri [URI::HTTPS] target URI
      # @param headers [Hash<String, String>] request headers
      # @yield [Net::HTTPResponse] for streaming responses
      # @return [Response] response object
      def get(uri, headers: {}, &) = request(:get, uri, headers:, &)

      # Execute a HEAD request
      #
      # @param uri [URI::HTTPS] target URI
      # @param headers [Hash<String, String>] request headers
      # @return [Response] response object
      def head(uri, headers: {}) = request(:head, uri, headers:)

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
          raise URLError, "Too many redirects (#{redirect_count})"
        end

        http = create_http(uri)
        req = build_request(method, uri, headers:, body:)

        result = nil
        http.request(req) do |response|
          result = handle_response(response, method, uri, redirect_count, &block)
        end
        result
      end

      private def handle_response(response, _method, uri, redirect_count, &block)
        case response
        when Net::HTTPSuccess, Net::HTTPPartialContent
          yield(response) if block
          Response.new(response, uri:)

        when Net::HTTPRedirection
          location = response["Location"]
          redirect_url = URI(location)
          logger.info("Following redirect", location: mask_credentials(redirect_url))

          perform_request(:get, redirect_url, redirect_count: redirect_count + 1, headers: {}, body: nil, &block)

        when Net::HTTPNotFound
          api_error, api_message = parse_api_error(response)
          logger.error("HTTP not found", code: response.code, message: response.message, api_message:)
          raise HTTPNotFoundError.new("#{response.code} #{response.message}", api_error:, api_message:)

        when Net::HTTPClientError
          api_error, api_message = parse_api_error(response)
          logger.error("HTTP client error", code: response.code, message: response.message, api_message:)
          raise HTTPClientError.new("#{response.code} #{response.message}", api_error:, api_message:)

        when Net::HTTPServerError
          logger.error("HTTP server error", code: response.code, message: response.message)
          raise HTTPServerError, "#{response.code} #{response.message}"

        else
          raise HTTPError, "#{response.code} #{response.message}"
        end
      rescue URI::InvalidURIError
        raise HTTPError, "Invalid redirect URI: #{response["Location"]}"
      end

      # Parse API error response body for error and message fields
      #
      # @param response [Net::HTTPResponse] HTTP response
      # @return [Array(String, String), Array(nil, nil)] tuple of [api_error, api_message]
      private def parse_api_error(response)
        return [nil, nil] unless response.content_type&.include?("application/json")

        body = response.body
        return [nil, nil] if body.nil? || body.empty?

        json = JSON.parse(body, symbolize_names: true)
        [json[:error], json[:message]]
      rescue JSON::ParserError
        [nil, nil]
      end

      private def build_request(method, uri, headers:, body:)
        request = case method
                  when :get then Net::HTTP::Get.new(uri)
                  when :head then Net::HTTP::Head.new(uri)
                  when :post then Net::HTTP::Post.new(uri)
                  when :put then Net::HTTP::Put.new(uri)
                  when :delete then Net::HTTP::Delete.new(uri)
                  else raise InvalidArgumentError, "Unsupported method: #{method}"
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
        Net::HTTP.new(uri.host, uri.port).tap do |http|
          http.use_ssl = uri.scheme == "https"
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.open_timeout = Factorix.config.http.connect_timeout
          http.read_timeout = Factorix.config.http.read_timeout
          http.write_timeout = Factorix.config.http.write_timeout if http.respond_to?(:write_timeout=)
        end
      end

      # Mask sensitive URL parameters for logging
      #
      # @param url [URI] URL to mask
      # @return [String] URL string with sensitive parameters masked
      private def mask_credentials(url)
        return url.to_s unless url.query
        return url.to_s if masked_params.empty?

        masked_url = url.dup
        params = URI.decode_www_form(masked_url.query).to_h
        masked_params.each {|key| params[key] = "*****" if params.key?(key) }
        masked_url.query = URI.encode_www_form(params)
        masked_url.to_s
      end
    end
  end
end
