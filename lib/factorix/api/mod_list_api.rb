# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "tempfile"
require "uri"

module Factorix
  module API
    # API client for retrieving mod list and details without authentication
    #
    # Corresponds to: https://wiki.factorio.com/Mod_portal_API
    class MODListAPI
      include Factorix::Import["api_cache"]

      BASE_URL = "https://mods.factorio.com"
      private_constant :BASE_URL

      # Retrieve mod list with optional filters
      #
      # @param params [Hash] query parameters (hide_deprecated, page, page_size, sort, sort_order, namelist, version)
      # @return [Hash{Symbol => untyped}] parsed JSON response with :results and :pagination keys
      def get_mods(**params)
        uri = build_uri("/api/mods", **params)
        fetch_with_cache(uri)
      end

      # Retrieve basic information for a specific mod
      #
      # @param name [String] mod name
      # @return [Hash{Symbol => untyped}] parsed JSON response with mod metadata and releases
      def get_mod(name)
        uri = build_uri("/api/mods/#{name}")
        fetch_with_cache(uri)
      end

      # Retrieve detailed information for a specific mod
      #
      # @param name [String] mod name
      # @return [Hash{Symbol => untyped}] parsed JSON response with full mod details including dependencies
      def get_mod_full(name)
        uri = build_uri("/api/mods/#{name}/full")
        fetch_with_cache(uri)
      end

      private def build_uri(path, **params)
        uri = URI.join(BASE_URL, path)
        uri.query = URI.encode_www_form(params.sort.to_h) unless params.empty?
        uri
      end

      # Fetch data with cache support
      #
      # @param uri [URI::HTTPS] URI to fetch
      # @return [Hash{Symbol => untyped}] parsed JSON response with symbolized keys
      private def fetch_with_cache(uri)
        key = api_cache.key_for(uri.to_s)

        # Try cache first
        cached = api_cache.read(key, encoding: "UTF-8")
        return JSON.parse(cached, symbolize_names: true) if cached

        # Cache miss - fetch from API
        response_body = fetch_from_api(uri)

        # Store in cache
        store_in_cache(key, response_body)

        JSON.parse(response_body, symbolize_names: true)
      end

      # Fetch data from API via HTTP
      #
      # @param uri [URI::HTTPS] URI to fetch
      # @return [String] response body
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      private def fetch_from_api(uri)
        http = create_http(uri)

        request = Net::HTTP::Get.new(uri)
        response = http.request(request)

        handle_http_errors(response)

        response.body
      end

      # Create and configure Net::HTTP instance
      #
      # @param uri [URI::HTTPS] URI to connect to
      # @return [Net::HTTP] configured HTTP client
      private def create_http(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.open_timeout = Application.config.http.connect_timeout
        http.read_timeout = Application.config.http.read_timeout
        http.write_timeout = Application.config.http.write_timeout if http.respond_to?(:write_timeout=)
        http
      end

      # Handle HTTP error responses
      #
      # @param response [Net::HTTPResponse] HTTP response
      # @return [void]
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      private def handle_http_errors(response)
        case response
        when Net::HTTPSuccess
          # OK
        when Net::HTTPClientError
          raise HTTPClientError, "#{response.code} #{response.message}"
        when Net::HTTPServerError
          raise HTTPServerError, "#{response.code} #{response.message}"
        else
          raise HTTPError, "#{response.code} #{response.message}"
        end
      end

      # Store response body in cache via temporary file
      #
      # @param key [String] cache key
      # @param data [String] response body
      # @return [void]
      private def store_in_cache(key, data)
        temp_file = Tempfile.new("api_cache")
        begin
          temp_file.write(data)
          temp_file.close
          api_cache.store(key, temp_file.path)
        ensure
          temp_file.unlink
        end
      end
    end
  end
end
