# frozen_string_literal: true

module Factorix
  # High-level API wrapper for Factorio MOD Portal
  #
  # Provides object-oriented interface by converting API responses (Hash)
  # to typed value objects (MODInfo, Release, etc.).
  #
  # @example List all MODs
  #   portal = Factorix::Portal.new
  #   mods = portal.list_mods(page_size: 10)
  #   mods.each { |mod| puts "#{mod.name}: #{mod.title}" }
  #
  # @example Get MOD information
  #   mod = portal.get_mod("space-exploration")
  #   puts mod.summary
  #
  # @example Get full MOD details
  #   mod = portal.get_mod_full("space-exploration")
  #   puts mod.detail.description if mod.detail
  #
  # @example Download a MOD
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

    # List MODs from the MOD Portal
    #
    # @param namelist [Array<String>] MOD names to filter (positional arguments)
    # @param hide_deprecated [Boolean, nil] hide deprecated MODs
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

    # Get basic information for a specific MOD (Short API)
    #
    # @param name [String] MOD name
    # @return [Types::MODInfo] MODInfo object (without Detail)
    def get_mod(name)
      data = mod_portal_api.get_mod(name)
      Types::MODInfo[**data]
    end

    # Get full information for a specific MOD (Full API)
    #
    # @param name [String] MOD name
    # @return [Types::MODInfo] MODInfo object (with Detail if available)
    def get_mod_full(name)
      data = mod_portal_api.get_mod_full(name)
      Types::MODInfo[**data]
    end

    # Download a MOD release file
    #
    # @param release [Types::Release] release object containing download_url and sha1
    # @param output [Pathname] output file path
    # @return [void]
    # @raise [ArgumentError] if release download_url is not a URI
    # @raise [DigestMismatchError] if SHA1 verification fails
    def download_mod(release, output)
      # Extract path from URI::HTTPS
      download_path = release.download_url.path
      mod_download_api.download(download_path, output, expected_sha1: release.sha1)
    end

    # Upload a MOD file to the portal
    #
    # Automatically detects if this is a new MOD or update:
    # - For new MODs: uses init_publish and includes metadata in finish_upload
    # - For existing MODs: uses init_upload, then updates metadata via edit_details
    #
    # @param mod_name [String] the MOD name
    # @param file_path [Pathname] path to MOD zip file
    # @param metadata [Hash] optional metadata
    # @option metadata [String] :description Markdown description
    # @option metadata [String] :category MOD category
    # @option metadata [String] :license License identifier
    # @option metadata [String] :source_url Repository URL
    # @return [void]
    # @raise [HTTPClientError] for 4xx errors
    # @raise [HTTPServerError] for 5xx errors
    def upload_mod(mod_name, file_path, **metadata)
      mod_exists = begin
        get_mod(mod_name)
        logger.info("Uploading new release to existing MOD", mod: mod_name)
        true
      rescue MODNotOnPortalError
        logger.info("Publishing new MOD", mod: mod_name)
        false
      end

      upload_url = if mod_exists
                     mod_management_api.init_upload(mod_name)
                   else
                     mod_management_api.init_publish(mod_name)
                   end

      if mod_exists
        # For existing MODs: upload file, then edit metadata separately
        mod_management_api.finish_upload(upload_url, file_path)
        mod_management_api.edit_details(mod_name, **metadata) unless metadata.empty?
      else
        # For new MODs: upload file with metadata
        mod_management_api.finish_upload(upload_url, file_path, **metadata)
      end

      logger.info("Upload completed successfully", mod: mod_name)
    end

    # Edit MOD metadata without uploading new file
    #
    # @param mod_name [String] the MOD name
    # @param metadata [Hash] metadata to update
    # @option metadata [String] :description Markdown description
    # @option metadata [String] :summary Brief description
    # @option metadata [String] :title MOD title
    # @option metadata [String] :category MOD category
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

      logger.info("Editing MOD metadata", mod: mod_name, fields: metadata.keys)
      mod_management_api.edit_details(mod_name, **metadata)
      logger.info("Metadata updated successfully", mod: mod_name)
    end

    # Add an image to a MOD
    #
    # @param mod_name [String] the MOD name
    # @param image_file [Pathname] path to image file
    # @return [Types::Image] the uploaded image info
    # @raise [HTTPClientError] for 4xx errors
    # @raise [HTTPServerError] for 5xx errors
    def add_mod_image(mod_name, image_file)
      logger.info("Adding image to MOD", mod: mod_name, file: image_file.to_s)

      # Initialize upload
      upload_url = mod_management_api.init_image_upload(mod_name)

      # Upload image
      response_data = mod_management_api.finish_image_upload(upload_url, image_file)

      # Convert response to Types::Image
      image = Types::Image[**response_data.transform_keys(&:to_sym)]

      logger.info("Image added successfully", mod: mod_name, image_id: image.id)
      image
    end

    # Edit MOD's image list
    #
    # @param mod_name [String] the MOD name
    # @param image_ids [Array<String>] array of image IDs in desired order
    # @return [void]
    # @raise [HTTPClientError] for 4xx errors
    # @raise [HTTPServerError] for 5xx errors
    def edit_mod_images(mod_name, image_ids)
      logger.info("Editing MOD images", mod: mod_name, image_count: image_ids.size)
      mod_management_api.edit_images(mod_name, image_ids)
      logger.info("Images updated successfully", mod: mod_name)
    end
  end
end
