# frozen_string_literal: true

require "json"
require "open-uri"
require "time"
require "uri"

require_relative "error"
require_relative "types"

module Factorix
  module ModPortal
    # API client for Factorio Mod Portal
    class API
      BASE_URL = URI("https://mods.factorio.com/api")
      private_constant :BASE_URL

      ASSETS_URL = URI("https://assets-mod.factorio.com")
      private_constant :ASSETS_URL

      VALID_SORT_FIELDS = %w[name created_at updated_at].freeze
      private_constant :VALID_SORT_FIELDS

      VALID_SORT_ORDERS = %w[asc desc].freeze
      private_constant :VALID_SORT_ORDERS

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

      # List mods from Mod Portal
      # @param hide_deprecated [Boolean] Only return non-deprecated mods
      # @param page [Integer] Page number you would like to show
      # @param page_size [Integer, "max"] The amount of results to show in your search
      # @param sort [String] Sort results by this property (name, created_at or updated_at)
      # @param sort_order [String] Sort results ascending or descending (asc or desc)
      # @param namelist [Array<String>] Return only mods that match the given names
      # @param version [String] Only return non-deprecated mods compatible with this Factorio version
      # @return [Types::ModList]
      # @raise [RequestError] when request fails (including timeouts)
      # @raise [ResponseError] when response cannot be parsed
      # @raise [ValidationError] when parameters are invalid
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

      # Get information about a specific mod
      # @param name [String] The mod's name
      # @return [Types::Mod]
      # @raise [RequestError] when request fails (including timeouts)
      # @raise [ResponseError] when response cannot be parsed
      def mod(name)
        response = request("/mods/#{name}")
        parse_mod(response)
      end

      # Get detailed information about a specific mod
      # @param name [String] The mod's name
      # @return [Types::ModWithDetails]
      # @raise [RequestError] when request fails (including timeouts)
      # @raise [ResponseError] when response cannot be parsed
      def mod_with_details(name)
        response = request("/mods/#{name}/full")
        parse_mod_with_details(response)
      end

      private def request(path, **params)
        uri = BASE_URL.dup
        uri.path = File.join(uri.path, path)
        uri.query = URI.encode_www_form(params) unless params.empty?

        JSON.parse(uri.read(open_timeout: 5, read_timeout: 10))
      rescue OpenURI::HTTPError => e
        raise RequestError, e.message
      rescue Net::OpenTimeout => e
        raise RequestError, "connection timeout: #{e.message}"
      rescue Net::ReadTimeout => e
        raise RequestError, "read timeout: #{e.message}"
      rescue OpenSSL::SSL::SSLError => e
        raise RequestError, "SSL/TLS error: #{e.message}"
      rescue SocketError => e
        raise RequestError, "network error: #{e.message}"
      rescue SystemCallError => e
        raise RequestError, "connection error: #{e.message}"
      rescue JSON::ParserError => e
        raise ResponseError, e.message
      end

      private def parse_mod_list(json)
        pagination = parse_pagination(json["pagination"])
        results = json["results"].map {|result| parse_mod_entry(result) }

        raise TypeError, "pagination must be a Pagination" unless pagination.is_a?(Types::Pagination)
        raise TypeError, "results must be an Array of ModEntry" unless results.is_a?(Array) && results.all?(Types::ModEntry)

        Types::ModList[results:, pagination:]
      end

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

      private def parse_license(json)
        Types::License[description: json["description"]]
      end

      private def parse_time(time_str)
        return nil if time_str.nil?

        begin
          Time.iso8601(time_str).utc
        rescue ArgumentError
          nil
        end
      end

      private def to_absolute_url(path)
        return nil if path.nil?

        case path
        when %r{\A/assets/}
          ASSETS_URL.dup.tap {|url| url.path = path }
        else
          BASE_URL.dup.tap {|url| url.path = path }
        end
      end

      private def validate_sort(sort)
        return if sort.nil?

        valid_sorts = %w[name created_at updated_at]
        raise ValidationError, "invalid sort: #{sort}" unless valid_sorts.include?(sort)
      end

      private def validate_sort_order(sort_order)
        return if VALID_SORT_ORDERS.include?(sort_order)

        raise ValidationError, "Invalid sort order: #{sort_order}. Valid values are: #{VALID_SORT_ORDERS.join(", ")}"
      end

      private def validate_version(version)
        return if VALID_VERSIONS.include?(version)

        raise ValidationError, "Invalid version: #{version}. Valid values are: #{VALID_VERSIONS.join(", ")}"
      end

      private def normalize_category(category)
        CATEGORY_NAMES.fetch(category.downcase, category)
      end
    end
  end
end
