# frozen_string_literal: true

module Factorix
  # High-level API wrapper for Factorio Mod Portal
  #
  # Provides object-oriented interface by converting API responses (Hash)
  # to typed value objects (MODInfo, Release, etc.).
  #
  # @example List all mods
  #   portal = Factorix::Portal.new
  #   mods = portal.list_mods(page_size: 10)
  #   mods.each { |mod| puts "#{mod.name}: #{mod.title}" }
  #
  # @example Get mod information
  #   mod = portal.get_mod("space-exploration")
  #   puts mod.summary
  #
  # @example Get full mod details
  #   mod = portal.get_mod_full("space-exploration")
  #   puts mod.detail.description if mod.detail
  #
  # @example Download a mod
  #   mod = portal.get_mod_full("space-exploration")
  #   release = mod.releases.max_by(&:released_at)  # Get latest by release date
  #   portal.download_mod(release, Pathname("downloads/mod.zip")) if release
  class Portal
    include Factorix::Import["mod_list_api", "mod_download_api"]

    # List mods from the Mod Portal
    #
    # @param namelist [Array<String>] mod names to filter (positional arguments)
    # @param hide_deprecated [Boolean, nil] hide deprecated mods
    # @param page [Integer, nil] page number (1-based)
    # @param page_size [Integer, nil] number of results per page
    # @param sort [String, nil] sort field (name, created_at, updated_at)
    # @param sort_order [String, nil] sort order (asc, desc)
    # @param version [String, nil] Factorio version filter
    # @return [Array<Types::MODInfo>] array of MODInfo objects
    def list_mods(...)
      response = mod_list_api.get_mods(...)
      response[:results].map {|mod_data| Types::MODInfo.new(**mod_data) }
    end

    # Get basic information for a specific mod (Short API)
    #
    # @param name [String] mod name
    # @return [Types::MODInfo] MODInfo object (without Detail)
    def get_mod(name)
      data = mod_list_api.get_mod(name)
      Types::MODInfo.new(**data)
    end

    # Get full information for a specific mod (Full API)
    #
    # @param name [String] mod name
    # @return [Types::MODInfo] MODInfo object (with Detail if available)
    def get_mod_full(name)
      data = mod_list_api.get_mod_full(name)
      Types::MODInfo.new(**data)
    end

    # Download a mod release file
    #
    # @param release [Types::Release] release object containing download_url
    # @param output [Pathname, String] output file path
    # @return [void]
    # @raise [ArgumentError] if release download_url is not a URI
    def download_mod(release, output)
      output = Pathname(output) unless output.is_a?(Pathname)

      # Extract path from URI::HTTPS
      download_path = release.download_url.path
      mod_download_api.download(download_path, output)
    end
  end
end
