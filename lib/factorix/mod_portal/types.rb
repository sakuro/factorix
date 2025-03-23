# frozen_string_literal: true

require "uri"

module Factorix
  module ModPortal
    # Data types for ModPortal API
    # This module contains all the data types used to represent ModPortal API responses
    module Types
      # Pagination information for list responses
      #
      # @!attribute page [Integer] Current page number
      # @!attribute page_count [Integer] Total number of pages
      # @!attribute page_size [Integer] Number of items per page
      # @!attribute count [Integer] Total number of items
      # @!attribute links [PaginationLinks] Links to other pages
      Pagination = Data.define(:page, :page_count, :page_size, :count, :links)

      # Links to navigate between pages in paginated responses
      #
      # @!attribute first [String] URL to the first page
      # @!attribute prev [String, nil] URL to the previous page, nil if on first page
      # @!attribute next [String, nil] URL to the next page, nil if on last page
      # @!attribute last [String] URL to the last page
      PaginationLinks = Data.define(:first, :prev, :next, :last)

      # Information about a specific mod release.
      #
      # @!attribute version [String] Version number of the release
      # @!attribute released_at [Time] When the release was published
      # @!attribute download_url [URI] URL to download the release
      # @!attribute file_name [String] Name of the release file
      # @!attribute sha1 [String] SHA1 hash of the release file
      # @!attribute info_json [Hash] Contents of the info.json file
      Release = Data.define(:version, :released_at, :download_url, :file_name, :sha1, :info_json)

      # License information for a mod.
      #
      # @!attribute description [String] Description of the license
      License = Data.define(:description)

      # Basic information about a mod as shown in search results
      #
      # @!attribute name [String] Internal name of the mod
      # @!attribute title [String] Display name of the mod
      # @!attribute owner [String] Username of the mod owner
      # @!attribute summary [String] Short description of the mod
      # @!attribute downloads_count [Integer] Number of times the mod has been downloaded
      # @!attribute category [String] Category the mod belongs to
      # @!attribute thumbnail [URI, nil] URL to the mod's thumbnail image
      # @!attribute score [Float] Popularity score of the mod
      # @!attribute latest_release [Release, nil] Information about the latest release
      # @!attribute releases [Array<Release>, nil] List of all releases
      ModEntry = Data.define(
        :name,
        :title,
        :owner,
        :summary,
        :downloads_count,
        :category,
        :thumbnail,
        :score,
        :latest_release,
        :releases
      )

      # Basic information about a mod when fetched individually.
      # Similar to ModEntry but always includes all releases.
      #
      # @!attribute name [String] Internal name of the mod
      # @!attribute title [String] Display name of the mod
      # @!attribute owner [String] Username of the mod owner
      # @!attribute summary [String] Short description of the mod
      # @!attribute downloads_count [Integer] Number of times the mod has been downloaded
      # @!attribute category [String] Category the mod belongs to
      # @!attribute thumbnail [URI, nil] URL to the mod's thumbnail image
      # @!attribute score [Float] Popularity score of the mod
      # @!attribute releases [Array<Release>] List of all releases
      Mod = Data.define(
        :name,
        :title,
        :owner,
        :summary,
        :downloads_count,
        :category,
        :thumbnail,
        :score,
        :releases
      )

      # Detailed information about a mod.
      # Includes all information from Mod plus additional details.
      #
      # @!attribute name [String] Internal name of the mod
      # @!attribute title [String] Display name of the mod
      # @!attribute owner [String] Username of the mod owner
      # @!attribute summary [String] Short description of the mod
      # @!attribute downloads_count [Integer] Number of times the mod has been downloaded
      # @!attribute category [String] Category the mod belongs to
      # @!attribute thumbnail [URI, nil] URL to the mod's thumbnail image
      # @!attribute score [Float] Popularity score of the mod
      # @!attribute releases [Array<Release>] List of all releases
      # @!attribute created_at [Time] When the mod was first published
      # @!attribute updated_at [Time] When the mod was last updated
      # @!attribute last_highlighted_at [Time, nil] When the mod was last featured
      # @!attribute description [String] Full description of the mod
      # @!attribute homepage [String, nil] URL to the mod's homepage
      # @!attribute source_url [String, nil] URL to the mod's source code
      # @!attribute tags [Array<String>] List of tags associated with the mod
      # @!attribute license [License, nil] License information
      # @!attribute deprecated [Boolean] Whether the mod is deprecated
      # @!attribute changelog [String, nil] Changelog text
      # @!attribute github_path [String, nil] Path to the mod's GitHub repository
      ModWithDetails = Data.define(
        :name,
        :title,
        :owner,
        :summary,
        :downloads_count,
        :category,
        :thumbnail,
        :score,
        :releases,
        :created_at,
        :updated_at,
        :last_highlighted_at,
        :description,
        :homepage,
        :source_url,
        :tags,
        :license,
        :deprecated,
        :changelog,
        :github_path
      )

      # List of mods with pagination information.
      #
      # @!attribute results [Array<ModEntry>] List of mods in the current page.
      # @!attribute pagination [Pagination] Pagination information.
      ModList = Data.define(:results, :pagination)
    end
  end
end
