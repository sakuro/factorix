# frozen_string_literal: true

require "time"
require "uri"

module Factorix
  module Types
    Release = Data.define(
      :download_url,
      :file_name,
      :info_json,
      :released_at,
      :version,
      :sha1
    )

    # Release object from Mod Portal API
    #
    # Represents a specific version/release of a MOD
    #
    # @see https://wiki.factorio.com/Mod_portal_API#Releases
    class Release
      # @!attribute [r] download_url
      #   @return [URI::HTTPS] absolute URL for downloading this release
      # @!attribute [r] file_name
      #   @return [String] file name of the release archive
      # @!attribute [r] info_json
      #   @return [Hash] info.json metadata from the MOD
      # @!attribute [r] released_at
      #   @return [Time] release timestamp in UTC
      # @!attribute [r] version
      #   @return [MODVersion] MOD version object
      # @!attribute [r] sha1
      #   @return [String] SHA1 checksum of the release file

      # Create Release from API response hash
      #
      # @param download_url [String] relative download URL path
      # @param file_name [String] release file name
      # @param info_json [Hash] info.json metadata
      # @param released_at [String] ISO 8601 timestamp
      # @param version [String] version string in "X.Y.Z" format
      # @param sha1 [String] SHA1 checksum
      # @return [Release] new Release instance
      def initialize(download_url:, file_name:, info_json:, released_at:, version:, sha1:)
        download_url = URI("https://mods.factorio.com#{download_url}")
        released_at = Time.parse(released_at).utc
        version = MODVersion.from_string(version)
        super
      end
    end
  end
end
