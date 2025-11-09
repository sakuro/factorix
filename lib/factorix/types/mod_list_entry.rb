# frozen_string_literal: true

module Factorix
  module Types
    MODListEntry = Data.define(
      :name,
      :title,
      :owner,
      :summary,
      :downloads_count,
      :category,
      :score,
      :latest_release,
      :releases
    )

    # MOD list entry from /api/mods endpoint
    #
    # Represents a single mod entry from the mod list API.
    # Note: The API returns either `latest_release` OR `releases` depending on parameters:
    # - Without namelist parameter: includes `latest_release` (single Release)
    # - With namelist parameter: includes `releases` (array of Releases), no `latest_release`
    #
    # @see https://wiki.factorio.com/Mod_portal_API#Result_Entry
    class MODListEntry
      # @!attribute [r] name
      #   @return [String] internal mod name (unique identifier)
      # @!attribute [r] title
      #   @return [String] human-readable mod title
      # @!attribute [r] owner
      #   @return [String] mod owner username
      # @!attribute [r] summary
      #   @return [String] short description of the mod
      # @!attribute [r] downloads_count
      #   @return [Integer] total number of downloads
      # @!attribute [r] category
      #   @return [Category] mod category
      # @!attribute [r] score
      #   @return [Float] mod score/rating
      # @!attribute [r] latest_release
      #   @return [Release, nil] latest release (present when called without namelist parameter)
      # @!attribute [r] releases
      #   @return [Array<Release>, nil] all releases, oldest first (present when called with namelist parameter)

      # Create MODListEntry from API response hash
      #
      # @param name [String] mod name
      # @param title [String] mod title
      # @param owner [String] mod owner username
      # @param summary [String] mod summary
      # @param downloads_count [Integer] total downloads
      # @param category [String] category value
      # @param score [Float] mod score
      # @param latest_release [Hash, nil] latest release data
      # @param releases [Array<Hash>, nil] releases data
      # @return [MODListEntry] new MODListEntry instance
      def initialize(name:, title:, owner:, summary:, downloads_count:, category:, score:, latest_release: nil, releases: nil)
        category = Category.for(category)
        latest_release = latest_release ? Release.new(**latest_release) : nil
        releases = releases&.then {|rs| rs.empty? ? nil : rs.map {|r| Release.new(**r) } }
        super
      end
    end
  end
end
