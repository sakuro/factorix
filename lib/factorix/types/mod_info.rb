# frozen_string_literal: true

require "time"
require "uri"

module Factorix
  module Types
    MODInfo = Data.define(
      :name,
      :title,
      :owner,
      :summary,
      :downloads_count,
      :category,
      :score,
      :thumbnail,
      :latest_release,
      :releases,
      :detail
    )

    # MOD information from Mod Portal API
    #
    # Represents MOD metadata from various API endpoints:
    # - /api/mods (list)
    # - /api/mods/{name} (Short)
    # - /api/mods/{name}/full (Full)
    #
    # @see https://wiki.factorio.com/Mod_portal_API
    class MODInfo
      # @!attribute [r] name
      #   @return [String] internal MOD name (unique identifier)
      # @!attribute [r] title
      #   @return [String] human-readable MOD title
      # @!attribute [r] owner
      #   @return [String] MOD owner username
      # @!attribute [r] summary
      #   @return [String] short description
      # @!attribute [r] downloads_count
      #   @return [Integer] total number of downloads
      # @!attribute [r] category
      #   @return [Category] MOD category
      # @!attribute [r] score
      #   @return [Float] MOD score/rating
      # @!attribute [r] thumbnail
      #   @return [URI::HTTPS, nil] thumbnail image URL
      # @!attribute [r] latest_release
      #   @return [Release, nil] latest release (list API without namelist)
      # @!attribute [r] releases
      #   @return [Array<Release>] all releases
      # @!attribute [r] detail
      #   @return [Detail, nil] detailed information (Full API only)

      Detail = Data.define(
        :changelog,
        :created_at,
        :updated_at,
        :last_highlighted_at,
        :description,
        :source_url,
        :homepage,
        :faq,
        :tags,
        :license,
        :images,
        :deprecated
      )

      # Detailed MOD information from Full API endpoint
      #
      # @see https://wiki.factorio.com/Mod_portal_API
      class Detail
        # @!attribute [r] changelog
        #   @return [String] changelog text
        # @!attribute [r] created_at
        #   @return [Time] creation timestamp
        # @!attribute [r] updated_at
        #   @return [Time] last update timestamp
        # @!attribute [r] last_highlighted_at
        #   @return [Time, nil] last highlighted timestamp
        # @!attribute [r] description
        #   @return [String] detailed description text
        # @!attribute [r] source_url
        #   @return [URI::HTTPS, nil] source repository URL
        # @!attribute [r] homepage
        #   @return [URI, String] homepage URL or string
        # @!attribute [r] faq
        #   @return [String] FAQ text
        # @!attribute [r] tags
        #   @return [Array<Tag>] tags
        # @!attribute [r] license
        #   @return [License, nil] license information
        # @!attribute [r] images
        #   @return [Array<Image>] images
        # @!attribute [r] deprecated
        #   @return [Boolean] deprecation status

        # Create Detail from API response hash
        #
        # @param changelog [String, nil] changelog
        # @param created_at [String] ISO 8601 timestamp
        # @param updated_at [String] ISO 8601 timestamp
        # @param last_highlighted_at [String, nil] ISO 8601 timestamp
        # @param description [String, nil] description
        # @param source_url [String, nil] source URL
        # @param homepage [String] homepage URL or string
        # @param faq [String, nil] FAQ
        # @param tags [Array<String>, nil] tags
        # @param license [Hash, nil] license data
        # @param images [Array<Hash>, nil] images data
        # @param deprecated [Boolean, nil] deprecated flag
        # @return [Detail] new Detail instance
        def initialize(
          created_at:,
          updated_at:,
          homepage:,
          changelog: nil,
          last_highlighted_at: nil,
          description: nil,
          source_url: nil,
          faq: nil,
          tags: nil,
          license: nil,
          images: nil,
          deprecated: nil
        )
          changelog ||= ""
          created_at = Time.parse(created_at).utc
          updated_at = Time.parse(updated_at).utc
          last_highlighted_at = last_highlighted_at ? Time.parse(last_highlighted_at).utc : nil
          description ||= ""
          source_url = source_url ? URI(source_url) : nil
          homepage = parse_homepage(homepage)
          faq ||= ""
          tags = (tags || []).map {|tag_value| Tag.for(tag_value) }
          license = license ? License[**license] : nil
          images = (images || []).map {|img| Image[**img] }
          deprecated ||= false

          super
        end

        # Check if the MOD is deprecated
        #
        # @return [Boolean] true if deprecated
        def deprecated?
          deprecated
        end

        private def parse_homepage(value)
          URI(value)
        rescue URI::InvalidURIError
          value
        end
      end

      # Create MODInfo from API response hash
      #
      # @param name [String] MOD name
      # @param title [String] MOD title
      # @param owner [String] owner username
      # @param summary [String, nil] summary
      # @param downloads_count [Integer] download count
      # @param category [String, nil] category value
      # @param score [Float, nil] score
      # @param thumbnail [String, nil] thumbnail path
      # @param latest_release [Hash, nil] latest release data
      # @param releases [Array<Hash>, nil] releases data
      # @param detail [Hash, nil] detail data
      # @return [MODInfo] new MODInfo instance
      def initialize(
        name:,
        title:,
        owner:,
        downloads_count:,
        summary: nil,
        category: nil,
        score: nil,
        thumbnail: nil,
        latest_release: nil,
        releases: nil,
        **detail_fields
      )
        summary ||= ""
        category = Category.for(category || "")
        score ||= 0.0
        thumbnail = thumbnail ? build_thumbnail_uri(thumbnail) : nil
        latest_release = latest_release ? Release[**latest_release] : nil
        releases = (releases || []).map {|r| Release[**r] }

        # Filter detail_fields to only include keys that Detail.new accepts
        # Exclude deprecated fields like github_path
        detail = if all_required_detail_fields?(detail_fields)
                   allowed_keys = %i[
                     changelog
                     created_at
                     updated_at
                     last_highlighted_at
                     description
                     source_url
                     homepage
                     faq
                     tags
                     license
                     images
                     deprecated
                   ]
                   filtered_fields = detail_fields.slice(*allowed_keys)
                   Detail.new(**filtered_fields)
                 end

        super(
          name:,
          title:,
          owner:,
          summary:,
          downloads_count:,
          category:,
          score:,
          thumbnail:,
          latest_release:,
          releases:,
          detail:
        )
      end

      private def build_thumbnail_uri(path)
        URI("https://assets-mod.factorio.com#{path}")
      end

      # Check if detail_fields contains all required fields for Detail
      private def all_required_detail_fields?(detail_fields)
        %i[created_at updated_at homepage].all? {|field| detail_fields.key?(field) }
      end
    end
  end
end
