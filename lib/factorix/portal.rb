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
    # @!parse
    #   # @return [API::MODPortalAPI]
    #   attr_reader :mod_portal_api
    #   # @return [API::MODDownloadAPI]
    #   attr_reader :mod_download_api
    #   # @return [API::MODManagementAPI]
    #   attr_reader :mod_management_api
    #   # @return [Dry::Logger::Dispatcher]
    #   attr_reader :logger
    include Import[:mod_portal_api, :mod_download_api, :mod_management_api, :logger]

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
      response = mod_portal_api.get_mods(...)
      response[:results].map {|mod_data| Types::MODInfo[**mod_data] }
    end

    # Get basic information for a specific mod (Short API)
    #
    # @param name [String] mod name
    # @return [Types::MODInfo] MODInfo object (without Detail)
    def get_mod(name)
      data = mod_portal_api.get_mod(name)
      Types::MODInfo[**data]
    end

    # Get full information for a specific mod (Full API)
    #
    # @param name [String] mod name
    # @return [Types::MODInfo] MODInfo object (with Detail if available)
    def get_mod_full(name)
      data = mod_portal_api.get_mod_full(name)
      Types::MODInfo[**data]
    end

    # Download a mod release file
    #
    # @param release [Types::Release] release object containing download_url
    # @param output [Pathname] output file path
    # @return [void]
    # @raise [ArgumentError] if release download_url is not a URI
    def download_mod(release, output)
      # Extract path from URI::HTTPS
      download_path = release.download_url.path
      mod_download_api.download(download_path, output)
    end

    # Upload a mod file to the portal
    #
    # Automatically detects if this is a new mod or update:
    # - For new mods: uses init_publish and includes metadata in finish_upload
    # - For existing mods: uses init_upload, then updates metadata via edit_details
    #
    # @param mod_name [String] the mod name
    # @param file_path [Pathname] path to mod zip file
    # @param metadata [Hash] optional metadata
    # @option metadata [String] :description Markdown description
    # @option metadata [String] :category Mod category
    # @option metadata [String] :license License identifier
    # @option metadata [String] :source_url Repository URL
    # @return [void]
    # @raise [HTTPClientError] for 4xx errors
    # @raise [HTTPServerError] for 5xx errors
    def upload_mod(mod_name, file_path, **metadata)
      # Check if mod exists
      mod_exists = begin
        get_mod(mod_name)
        logger.info("Uploading new release to existing mod", mod: mod_name)
        true
      rescue MODNotOnPortalError
        logger.info("Publishing new mod", mod: mod_name)
        false
      end

      # Initialize upload with appropriate endpoint
      upload_url = if mod_exists
                     mod_management_api.init_upload(mod_name)
                   else
                     mod_management_api.init_publish(mod_name)
                   end

      # Complete upload
      if mod_exists
        # For existing mods: upload file, then edit metadata separately
        mod_management_api.finish_upload(upload_url, file_path)
        mod_management_api.edit_details(mod_name, **metadata) unless metadata.empty?
      else
        # For new mods: upload file with metadata
        mod_management_api.finish_upload(upload_url, file_path, **metadata)
      end

      logger.info("Upload completed successfully", mod: mod_name)
    end

    # Edit mod metadata without uploading new file
    #
    # @param mod_name [String] the mod name
    # @param metadata [Hash] metadata to update
    # @option metadata [String] :description Markdown description
    # @option metadata [String] :summary Brief description
    # @option metadata [String] :title Mod title
    # @option metadata [String] :category Mod category
    # @option metadata [Array<String>] :tags Array of tags
    # @option metadata [String] :license License identifier
    # @option metadata [String] :homepage Homepage URL
    # @option metadata [String] :source_url Repository URL
    # @option metadata [String] :faq FAQ text
    # @option metadata [Boolean] :deprecated Deprecation flag
    # @return [void]
    # @raise [ArgumentError] if no metadata provided
    # @raise [HTTPClientError] for 4xx errors
    # @raise [HTTPServerError] for 5xx errors
    def edit_mod(mod_name, **metadata)
      raise ArgumentError, "No metadata provided" if metadata.empty?

      logger.info("Editing mod metadata", mod: mod_name, fields: metadata.keys)
      mod_management_api.edit_details(mod_name, **metadata)
      logger.info("Metadata updated successfully", mod: mod_name)
    end

    # Add an image to a mod
    #
    # @param mod_name [String] the mod name
    # @param image_file [Pathname] path to image file
    # @return [Types::Image] the uploaded image info
    # @raise [HTTPClientError] for 4xx errors
    # @raise [HTTPServerError] for 5xx errors
    def add_mod_image(mod_name, image_file)
      logger.info("Adding image to mod", mod: mod_name, file: image_file.to_s)

      # Initialize upload
      upload_url = mod_management_api.init_image_upload(mod_name)

      # Upload image
      response_data = mod_management_api.finish_image_upload(upload_url, image_file)

      # Convert response to Types::Image
      image = Types::Image[**response_data.transform_keys(&:to_sym)]

      logger.info("Image added successfully", mod: mod_name, image_id: image.id)
      image
    end

    # Edit mod's image list
    #
    # @param mod_name [String] the mod name
    # @param image_ids [Array<String>] array of image IDs in desired order
    # @return [void]
    # @raise [HTTPClientError] for 4xx errors
    # @raise [HTTPServerError] for 5xx errors
    def edit_mod_images(mod_name, image_ids)
      logger.info("Editing mod images", mod: mod_name, image_count: image_ids.size)
      mod_management_api.edit_images(mod_name, image_ids)
      logger.info("Images updated successfully", mod: mod_name)
    end
  end
end
