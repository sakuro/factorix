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
    class MODPortalAPI
      # @!parse
      #   # @return [Cache::FileSystem]
      #   attr_reader :api_cache
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      include Factorix::Import["api_cache", "logger"]

      BASE_URL = "https://mods.factorio.com"
      private_constant :BASE_URL

      # Retrieve mod list with optional filters
      #
      # @param namelist [Array<String>] mod names to filter (positional arguments, sorted for cache consistency)
      # @param hide_deprecated [Boolean, nil] hide deprecated mods
      # @param page [Integer, nil] page number (1-based)
      # @param page_size [Integer, String, nil] number of results per page (positive integer or "max")
      # @param sort [String, nil] sort field (name, created_at, updated_at)
      # @param sort_order [String, nil] sort order (asc, desc)
      # @param version [String, nil] Factorio version filter
      # @return [Hash{Symbol => untyped}] parsed JSON response with :results and :pagination keys
      def get_mods(
        *namelist,
        hide_deprecated: nil,
        page: nil,
        page_size: nil,
        sort: nil,
        sort_order: nil,
        version: nil
      )
        validate_page_size!(page_size) if page_size
        validate_sort!(sort) if sort
        validate_sort_order!(sort_order) if sort_order
        validate_version!(version) if version

        params = {
          namelist: namelist.sort,
          hide_deprecated:,
          page:,
          page_size:,
          sort:,
          sort_order:,
          version:
        }
        params.reject! {|_k, v| v.is_a?(Array) && v.empty? }
        params.compact!
        logger.debug "Fetching mod list: params=#{params.inspect}"
        uri = build_uri("/api/mods", **params)
        fetch_with_cache(uri)
      end

      # Retrieve basic information for a specific mod
      #
      # @param name [String] mod name
      # @return [Hash{Symbol => untyped}] parsed JSON response with mod metadata and releases
      def get_mod(name)
        logger.debug "Fetching mod: name=#{name}"
        uri = build_uri("/api/mods/#{name}")
        fetch_with_cache(uri)
      end

      # Retrieve detailed information for a specific mod
      #
      # @param name [String] mod name
      # @return [Hash{Symbol => untyped}] parsed JSON response with full mod details including dependencies
      def get_mod_full(name)
        logger.debug "Fetching full mod info: name=#{name}"
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
        if cached
          logger.debug("API cache hit", uri: uri.to_s)
          return JSON.parse(cached, symbolize_names: true)
        end

        # Cache miss - fetch from API
        logger.debug("API cache miss", uri: uri.to_s)
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
        logger.info("Fetching from API", uri: uri.to_s)
        http = create_http(uri)

        request = Net::HTTP::Get.new(uri)
        response = http.request(request)

        handle_http_errors(response)

        logger.info("API response", code: response.code, size_bytes: response.body.bytesize)
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
          logger.error("API client error", code: response.code, message: response.message)
          raise HTTPClientError, "#{response.code} #{response.message}"
        when Net::HTTPServerError
          logger.error("API server error", code: response.code, message: response.message)
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
          logger.debug("Stored API response in cache", key:)
        ensure
          temp_file.unlink
        end
      end

      # Validate page_size parameter
      #
      # @param page_size [Integer, String] page size value
      # @return [void]
      # @raise [ArgumentError] if page_size is invalid
      private def validate_page_size!(page_size)
        return if page_size == "max"
        return if page_size.is_a?(Integer) && page_size.positive?

        raise ArgumentError, "page_size must be a positive integer or 'max', got: #{page_size.inspect}"
      end

      # Validate sort parameter
      #
      # @param sort [String] sort field name
      # @return [void]
      # @raise [ArgumentError] if sort is invalid
      private def validate_sort!(sort)
        valid_sorts = %w[name created_at updated_at]
        return if valid_sorts.include?(sort)

        raise ArgumentError, "sort must be one of #{valid_sorts.join(", ")}, got: #{sort.inspect}"
      end

      # Validate sort_order parameter
      #
      # @param sort_order [String] sort order
      # @return [void]
      # @raise [ArgumentError] if sort_order is invalid
      private def validate_sort_order!(sort_order)
        valid_orders = %w[asc desc]
        return if valid_orders.include?(sort_order)

        raise ArgumentError, "sort_order must be one of #{valid_orders.join(", ")}, got: #{sort_order.inspect}"
      end

      # Validate version parameter
      #
      # @param version [String] Factorio version
      # @return [void]
      # @raise [ArgumentError] if version is invalid
      private def validate_version!(version)
        valid_versions = %w[0.13 0.14 0.15 0.16 0.17 0.18 1.0 1.1 2.0]
        return if valid_versions.include?(version)

        raise ArgumentError, "version must be one of #{valid_versions.join(", ")}, got: #{version.inspect}"
      end
    end
  end
end
