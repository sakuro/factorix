# frozen_string_literal: true

require "json"
require "open-uri"
require "time"
require "uri"

require_relative "../errors"
require_relative "types"

module Factorix
  module ModPortal
    # API client for Factorio MOD Portal.
    # Provides methods to interact with the Factorio MOD Portal API,
    # including searching MODs, getting MOD details, and accessing MOD releases.
    class API
      # Base URL for the MOD Portal API.
      BASE_URL = URI("https://mods.factorio.com/api")
      private_constant :BASE_URL

      # Base URL for MOD assets (thumbnails, etc.)
      ASSETS_URL = URI("https://assets-mod.factorio.com")
      private_constant :ASSETS_URL

      # Valid fields for sorting MOD lists.
      VALID_SORT_FIELDS = %w[name created_at updated_at].freeze
      private_constant :VALID_SORT_FIELDS

      # Valid sort orders for MOD lists.
      VALID_SORT_ORDERS = %w[asc desc].freeze
      private_constant :VALID_SORT_ORDERS

      # Valid Factorio versions for MOD compatibility.
      VALID_VERSIONS = %w[0.13 0.14 0.15 0.16 0.17 0.18 1.0 1.1 2.0].freeze
      private_constant :VALID_VERSIONS

      # Category name mappings (API response => UI display)
      CATEGORY_NAMES = {
        "automation" => "Automation",
        "content" => "Content",
        "balance" => "Balance",
        "blueprints" => "Blueprints",
        "combat" => "Combat",
        "fixes" => "Fixes",
        "graphics" => "Graphics",
        "gui" => "GUI",
        "logistics" => "Logistics",
        "map-gen" => "Map Generation",
        "optimization" => "Optimization",
        "overhaul" => "Overhaul",
        "storage" => "Storage",
        "technology" => "Technology",
        "trains" => "Trains",
        "tweaks" => "Tweaks",
        "utilities" => "Utilities"
      }.freeze
      private_constant :CATEGORY_NAMES

      # List MODs from MOD Portal with various filtering and sorting options.
      # Results are paginated and can be filtered by various criteria.
      #
      # @param hide_deprecated [Boolean] Only return non-deprecated MODs.
      # @param page [Integer] Page number you would like to show.
      # @param page_size [Integer, "max"] The amount of results to show in your search.
      # @param sort [String] Sort results by this property (name, created_at or updated_at).
      # @param sort_order [String] Sort results ascending or descending (asc or desc).
      # @param namelist [Array<String>] Return only MODs that match the given names.
      # @param version [String] Only return non-deprecated MODs compatible with this Factorio version.
      # @return [Types::ModList]
      # @raise [Factorix::ModPortalRequestError] when request fails (including timeouts)
      # @raise [Factorix::ModPortalResponseError] when response cannot be parsed
      # @raise [Factorix::ModPortalValidationError] when parameters are invalid
      def mods(hide_deprecated: nil, page: nil, page_size: nil, sort: nil, sort_order: nil, namelist: nil, version: nil)
        validate_sort(sort) if sort
        validate_sort_order(sort_order) if sort_order
        validate_version(version) if version

        params = {
          hide_deprecated:,
          page:,
          page_size:,
          sort:,
          sort_order:,
          namelist: Array(namelist),
          version:
        }.compact

        response = request("/mods", **params)
        parse_mod_list(response)
      end

      # Get basic information about a specific MOD.
      # This includes the MOD's metadata and list of releases.
      #
      # @param name [String] The MOD's name.
      # @return [Types::Mod]
      # @raise [Factorix::ModPortalRequestError] when request fails (including timeouts)
      # @raise [Factorix::ModPortalResponseError] when response cannot be parsed
      def mod(name)
        response = request("/mods/#{name}")
        parse_mod(response)
      end

      # Get detailed information about a specific MOD
      # This includes all basic information plus additional details like
      # description, changelog, license, and more
      #
      # @param name [String] The MOD's name
      # @return [Types::ModWithDetails]
      # @raise [Factorix::ModPortalRequestError] when request fails (including timeouts)
      # @raise [Factorix::ModPortalResponseError] when response cannot be parsed
      def mod_with_details(name)
        response = request("/mods/#{name}/full")
        parse_mod_with_details(response)
      end

      # Make an HTTP request to the MOD Portal API
      # Handles various network errors and response parsing
      #
      # @param path [String] API endpoint path
      # @param params [Hash] Query parameters
      # @return [Hash] Parsed JSON response
      # @raise [Factorix::ModPortalRequestError] when request fails
      # @raise [Factorix::ModPortalResponseError] when response cannot be parsed
      private def request(path, **params)
        uri = BASE_URL.dup
        uri.path = File.join(uri.path, path)
        uri.query = URI.encode_www_form(params) unless params.empty?

        JSON.parse(uri.read(open_timeout: 5, read_timeout: 10))
      rescue OpenURI::HTTPError => e
        # Use more specific HTTP error classification
        if e.message.start_with?("4")
          raise Factorix::ModPortalRequestError, "Client error: #{e.message}"
        elsif e.message.start_with?("5")
          raise Factorix::ModPortalRequestError, "Server error: #{e.message}"
        else
          raise Factorix::ModPortalRequestError, "HTTP error: #{e.message}"
        end
      rescue Net::OpenTimeout => e
        raise Factorix::ModPortalRequestError, "Connection timeout: #{e.message}"
      rescue Net::ReadTimeout => e
        raise Factorix::ModPortalRequestError, "Read timeout: #{e.message}"
      rescue OpenSSL::SSL::SSLError => e
        raise Factorix::ModPortalRequestError, "SSL/TLS error: #{e.message}"
      rescue SocketError => e
        raise Factorix::ModPortalRequestError, "Network error: #{e.message}"
      rescue SystemCallError => e
        raise Factorix::ModPortalRequestError, "Connection error: #{e.message}"
      rescue JSON::ParserError => e
        raise Factorix::ModPortalResponseError, e.message
      end

      # Parse a MOD list response from the API.
      #
      # @param json [Hash] Raw JSON response.
      # @return [Types::ModList]
      # @raise [TypeError] if the response structure is invalid.
      private def parse_mod_list(json)
        pagination = parse_pagination(json["pagination"])
        results = json["results"].map {|result| parse_mod_entry(result) }

        raise TypeError, "pagination must be a Pagination" unless pagination.is_a?(Types::Pagination)
        raise TypeError, "results must be an Array of ModEntry" unless results.is_a?(Array) && results.all?(Types::ModEntry)

        Types::ModList[results:, pagination:]
      end

      # Parse pagination information from the API response.
      #
      # @param json [Hash] Raw JSON response.
      # @return [Types::Pagination]
      private def parse_pagination(json)
        links = json["links"]
        links = Types::PaginationLinks[
          first: links["first"],
          prev: links["prev"],
          next: links["next"],
          last: links["last"]
        ]

        Types::Pagination[
          page: json["page"],
          page_count: json["page_count"],
          page_size: json["page_size"],
          count: json["count"],
          links:
        ]
      end

      # Parse a MOD entry from the API response.
      #
      # @param json [Hash] Raw JSON response.
      # @return [Types::ModEntry]
      private def parse_mod_entry(json)
        Types::ModEntry[
          name: json["name"],
          title: json["title"],
          owner: json["owner"],
          summary: json["summary"],
          downloads_count: json["downloads_count"],
          category: normalize_category(json["category"]),
          thumbnail: json["thumbnail"] && to_absolute_url(json["thumbnail"]),
          score: json["score"],
          latest_release: json["latest_release"] && parse_release(json["latest_release"]),
          releases: json["releases"]&.map {|release| parse_release(release) }
        ]
      end

      # Parse basic MOD information from the API response.
      #
      # @param json [Hash] Raw JSON response.
      # @return [Types::Mod]
      private def parse_mod(json)
        Types::Mod[
          name: json["name"],
          title: json["title"],
          owner: json["owner"],
          summary: json["summary"],
          downloads_count: json["downloads_count"],
          category: normalize_category(json["category"]),
          thumbnail: json["thumbnail"] && to_absolute_url(json["thumbnail"]),
          score: json["score"],
          releases: json["releases"].map {|release| parse_release(release) }
        ]
      end

      # Parse detailed MOD information from the API response.
      #
      # @param json [Hash] Raw JSON response.
      # @return [Types::ModWithDetails]
      private def parse_mod_with_details(json)
        Types::ModWithDetails[
          name: json["name"],
          title: json["title"],
          owner: json["owner"],
          summary: json["summary"],
          downloads_count: json["downloads_count"],
          category: normalize_category(json["category"]),
          thumbnail: json["thumbnail"] && to_absolute_url(json["thumbnail"]),
          score: json["score"],
          releases: json["releases"].map {|release| parse_release(release) },
          created_at: parse_time(json["created_at"]),
          updated_at: parse_time(json["updated_at"]),
          last_highlighted_at: json["last_highlighted_at"] && parse_time(json["last_highlighted_at"]),
          description: json["description"],
          homepage: json["homepage"],
          source_url: json["source_url"],
          tags: json["tags"],
          license: json["license"] && parse_license(json["license"]),
          deprecated: json["deprecated"],
          changelog: json["changelog"],
          github_path: json["github_path"]
        ]
      end

      # Parse release information from the API response.
      #
      # @param json [Hash] Raw JSON response.
      # @return [Types::Release]
      private def parse_release(json)
        Types::Release[
          version: json["version"],
          released_at: parse_time(json["released_at"]),
          download_url: to_absolute_url(json["download_url"]),
          file_name: json["file_name"],
          sha1: json["sha1"],
          info_json: json["info_json"]
        ]
      end

      # Parse license information from the API response.
      #
      # @param json [Hash] Raw JSON response.
      # @return [Types::License]
      private def parse_license(json)
        Types::License[description: json["description"]]
      end

      # Parse an ISO8601 time string into a UTC Time object.
      #
      # @param time_str [String, nil] ISO8601 time string.
      # @return [Time, nil] Parsed time in UTC, or nil if input is nil or invalid.
      private def parse_time(time_str)
        return nil if time_str.nil?

        begin
          Time.iso8601(time_str).utc
        rescue ArgumentError
          nil
        end
      end

      # Convert a relative URL to an absolute URL
      # Assets URLs are prefixed with ASSETS_URL, others with BASE_URL
      #
      # @param path [String, nil] Relative URL path
      # @return [URI, nil] Absolute URL, or nil if input is nil
      private def to_absolute_url(path)
        return nil if path.nil?

        case path
        when %r{\A/assets/}
          ASSETS_URL.dup.tap {|url| url.path = path }
        else
          BASE_URL.dup.tap {|url| url.path = path }
        end
      end

      # Validate the sort parameter
      # @param sort [String] Sort field name
      # @raise [Factorix::ModPortalValidationError] if the sort field is invalid
      private def validate_sort(sort)
        return if sort.nil?

        valid_sorts = %w[name created_at updated_at]
        raise Factorix::ModPortalValidationError, "invalid sort: #{sort}" unless valid_sorts.include?(sort)
      end

      # Validate the sort order parameter
      # @param sort_order [String] Sort order (asc or desc)
      # @raise [Factorix::ModPortalValidationError] if the sort order is invalid
      private def validate_sort_order(sort_order)
        return if VALID_SORT_ORDERS.include?(sort_order)

        raise Factorix::ModPortalValidationError,
          "Invalid sort order: #{sort_order}. Valid values are: #{VALID_SORT_ORDERS.join(", ")}"
      end

      # Validate the version parameter
      # @param version [String] Factorio version
      # @raise [Factorix::ModPortalValidationError] if the version is invalid
      private def validate_version(version)
        return if VALID_VERSIONS.include?(version)

        raise Factorix::ModPortalValidationError,
          "Invalid version: #{version}. Valid values are: #{VALID_VERSIONS.join(", ")}"
      end

      # Normalize a category name to its display form
      # @param category [String] Raw category name from API
      # @return [String] Display form of the category name
      private def normalize_category(category)
        CATEGORY_NAMES.fetch(category.downcase, category)
      end
    end
  end
end
