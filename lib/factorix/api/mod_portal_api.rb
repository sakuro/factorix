# frozen_string_literal: true

require "erb"
require "json"
require "tempfile"
require "uri"

module Factorix
  module API
    # API client for retrieving MOD list and details without authentication
    #
    # Corresponds to: https://wiki.factorio.com/Mod_portal_API
    class MODPortalAPI
      # @!parse
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      #   # @return [Cache::FileSystem]
      #   attr_reader :cache
      #   # @return [HTTP::Client]
      #   attr_reader :client
      include Import[:logger, cache: :api_cache, client: :api_http_client]

      BASE_URL = "https://mods.factorio.com"
      private_constant :BASE_URL

      # Retrieve MOD list with optional filters
      #
      # @param namelist [Array<String>] MOD names to filter (positional arguments, sorted for cache consistency)
      # @param hide_deprecated [Boolean, nil] hide deprecated MODs
      # @param page [Integer, nil] page number (1-based)
      # @param page_size [Integer, String, nil] number of results per page (positive integer or "max")
      # @param sort [String, nil] sort field (name, created_at, updated_at)
      # @param sort_order [String, nil] sort order (asc, desc)
      # @param version [String, nil] Factorio version filter
      # @return [Hash{Symbol => untyped}] parsed JSON response with :results and :pagination keys
      def get_mods(*namelist, hide_deprecated: nil, page: nil, page_size: nil, sort: nil, sort_order: nil, version: nil)
        validate_page_size!(page_size) if page_size
        validate_sort!(sort) if sort
        validate_sort_order!(sort_order) if sort_order
        validate_version!(version) if version

        params = {namelist: namelist.sort, hide_deprecated:, page:, page_size:, sort:, sort_order:, version:}
        params.reject! {|_k, v| v.is_a?(Array) && v.empty? }
        params.compact!
        logger.debug "Fetching MOD list: params=#{params.inspect}"
        uri = build_uri("/api/mods", **params)
        fetch_with_cache(uri)
      end

      # Retrieve basic information for a specific MOD
      #
      # @param name [String] MOD name
      # @return [Hash{Symbol => untyped}] parsed JSON response with MOD metadata and releases
      # @raise [MODNotOnPortalError] if MOD not found on portal
      def get_mod(name)
        logger.debug "Fetching MOD: name=#{name}"
        encoded_name = ERB::Util.url_encode(name)
        uri = build_uri("/api/mods/#{encoded_name}")
        fetch_with_cache(uri)
      rescue HTTPNotFoundError => e
        raise MODNotOnPortalError, e.api_message || "MOD '#{name}' not found on portal"
      end

      # Retrieve detailed information for a specific MOD
      #
      # @param name [String] MOD name
      # @return [Hash{Symbol => untyped}] parsed JSON response with full MOD details including dependencies
      # @raise [MODNotOnPortalError] if MOD not found on portal
      def get_mod_full(name)
        logger.debug "Fetching full MOD info: name=#{name}"
        encoded_name = ERB::Util.url_encode(name)
        uri = build_uri("/api/mods/#{encoded_name}/full")
        fetch_with_cache(uri)
      rescue HTTPNotFoundError => e
        raise MODNotOnPortalError, e.api_message || "MOD '#{name}' not found on portal"
      end

      # Event handler for mod.changed event
      # Invalidates cached MOD information when a MOD is modified on the portal
      #
      # @param event [Dry::Events::Event] event with mod payload
      # @return [void]
      def on_mod_changed(event)
        mod_name = event[:mod]
        encoded_name = ERB::Util.url_encode(mod_name)

        # Invalidate get_mod cache
        mod_uri = build_uri("/api/mods/#{encoded_name}")
        mod_cache_key = mod_uri.to_s
        cache.with_lock(mod_cache_key) { cache.delete(mod_cache_key) }

        # Invalidate get_mod_full cache
        full_uri = build_uri("/api/mods/#{encoded_name}/full")
        full_cache_key = full_uri.to_s
        cache.with_lock(full_cache_key) { cache.delete(full_cache_key) }

        logger.debug("Invalidated cache for MOD", mod: mod_name)
      end

      private def build_uri(path, **params)
        URI.join(BASE_URL, path).tap {|uri| uri.query = URI.encode_www_form(params.sort.to_h) unless params.empty? }
      end

      # Fetch data with cache support
      #
      # @param uri [URI::HTTPS] URI to fetch
      # @return [Hash{Symbol => untyped}] parsed JSON response with symbolized keys
      private def fetch_with_cache(uri)
        cache_key = uri.to_s

        cached = cache.read(cache_key)
        if cached
          logger.debug("API cache hit", uri: uri.to_s)
          return JSON.parse((+cached).force_encoding(Encoding::UTF_8), symbolize_names: true)
        end

        logger.debug("API cache miss", uri: uri.to_s)
        response_body = fetch_from_api(uri)

        store_in_cache(cache_key, response_body)

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
        response = client.get(uri)
        logger.info("API response", code: response.code, size_bytes: response.body.bytesize)
        response.body
      end

      # Store response body in cache via temporary file
      #
      # @param cache_key [String] logical cache key (URL string)
      # @param data [String] response body
      # @return [void]
      private def store_in_cache(cache_key, data)
        temp_file = Tempfile.new("cache")
        begin
          temp_file.write(data)
          temp_file.close
          cache.store(cache_key, Pathname(temp_file.path))
          logger.debug("Stored API response in cache", key: cache_key)
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
