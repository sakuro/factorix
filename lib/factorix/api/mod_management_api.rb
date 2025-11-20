# frozen_string_literal: true

require "json"
require "uri"

module Factorix
  module API
    # API client for mod management operations (upload, publish, edit)
    #
    # Requires API key authentication via APICredential.
    # Uses api_credential lazy loading to avoid early environment variable evaluation.
    class MODManagementAPI
      # NOTE: api_credential is NOT imported to avoid early evaluation errors
      # when FACTORIO_API_KEY environment variable is not set.
      # It's resolved lazily via reader method instead.
      # @!parse
      #   # @return [HTTP::Client]
      #   attr_reader :client
      #   # @return [Transfer::Uploader]
      #   attr_reader :uploader
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      include Factorix::Import[:uploader, :logger, client: :http_client]

      BASE_URL = "https://mods.factorio.com"
      private_constant :BASE_URL

      # Metadata fields allowed in finish_upload (only for init_publish scenario)
      ALLOWED_UPLOAD_METADATA = %w[description category license source_url].freeze
      private_constant :ALLOWED_UPLOAD_METADATA

      # Metadata fields allowed in edit_details
      ALLOWED_EDIT_METADATA = %w[
        description
        summary
        title
        category
        tags
        license
        homepage
        source_url
        faq
        deprecated
      ].freeze
      private_constant :ALLOWED_EDIT_METADATA

      # Initialize with thread-safe credential loading
      #
      # @param args [Hash] dependency injection arguments
      def initialize(...)
        super
        @api_credential_mutex = Mutex.new
      end

      # Initialize new mod publication
      #
      # @param mod_name [String] the mod name
      # @return [URI::HTTPS] upload URL
      # @raise [HTTPClientError] for 4xx errors (e.g., mod already exists)
      # @raise [HTTPServerError] for 5xx errors
      def init_publish(mod_name)
        uri = URI.join(BASE_URL, "/api/v2/mods/releases/init_publish")
        body = JSON.generate({mod: mod_name})

        logger.info("Initializing mod publication", mod: mod_name)
        response = client.post(uri, body:, headers: build_auth_header, content_type: "application/json")

        parse_upload_url(response)
      end

      # Initialize update to existing mod
      #
      # @param mod_name [String] the mod name
      # @return [URI::HTTPS] upload URL
      # @raise [HTTPClientError] for 4xx errors (e.g., mod doesn't exist)
      # @raise [HTTPServerError] for 5xx errors
      def init_upload(mod_name)
        uri = URI.join(BASE_URL, "/api/v2/mods/releases/init_upload")
        body = JSON.generate({mod: mod_name})

        logger.info("Initializing mod upload", mod: mod_name)
        response = client.post(uri, body:, headers: build_auth_header, content_type: "application/json")

        parse_upload_url(response)
      end

      # Complete upload (works for both publish and update scenarios)
      #
      # @param upload_url [URI::HTTPS] the upload URL from init_publish or init_upload
      # @param file_path [Pathname, String] path to mod zip file
      # @param metadata [Hash] optional metadata (only used for init_publish)
      # @option metadata [String] :description Markdown description
      # @option metadata [String] :category Mod category
      # @option metadata [String] :license License identifier
      # @option metadata [String] :source_url Repository URL
      # @return [void]
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      def finish_upload(upload_url, file_path, **metadata)
        validate_metadata!(metadata, ALLOWED_UPLOAD_METADATA, "finish_upload")
        file_path = Pathname(file_path) unless file_path.is_a?(Pathname)

        logger.info("Uploading mod file", file: file_path.to_s, metadata_count: metadata.size)

        # Convert metadata keys to strings for form fields
        fields = metadata.transform_keys(&:to_s)

        uploader.upload(upload_url, file_path, fields:)
        logger.info("Upload completed successfully")
      end

      # Edit mod details (for post-upload metadata changes)
      #
      # @param mod_name [String] the mod name
      # @param metadata [Hash] metadata to update
      # @option metadata [String] :description Markdown description
      # @option metadata [String] :summary Brief description
      # @option metadata [String] :title Mod title
      # @option metadata [String] :category Mod category
      # @option metadata [Array<String>, String] :tags Array of tags or comma-separated string
      # @option metadata [String] :license License identifier
      # @option metadata [String] :homepage Homepage URL
      # @option metadata [String] :source_url Repository URL
      # @option metadata [String] :faq FAQ text
      # @option metadata [Boolean] :deprecated Deprecation flag
      # @return [void]
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      def edit_details(mod_name, **metadata)
        validate_metadata!(metadata, ALLOWED_EDIT_METADATA, "edit_details")

        # Convert tags array to comma-separated string if needed
        metadata = metadata.dup
        metadata[:tags] = metadata[:tags].join(",") if metadata[:tags].is_a?(Array)

        uri = URI.join(BASE_URL, "/api/v2/mods/edit_details")

        # Build form data
        form_data = {mod: mod_name, **metadata}.transform_keys(&:to_s)
        body = URI.encode_www_form(form_data)

        logger.info("Editing mod details", mod: mod_name, fields: metadata.keys)
        client.post(uri, body:, headers: build_auth_header, content_type: "application/x-www-form-urlencoded")
        logger.info("Edit completed successfully")
      end

      # Initialize image upload for a mod
      #
      # @param mod_name [String] the mod name
      # @return [URI::HTTPS] upload URL
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      def init_image_upload(mod_name)
        uri = URI.join(BASE_URL, "/api/v2/mods/images/add")
        body = JSON.generate({mod: mod_name})

        logger.info("Initializing image upload", mod: mod_name)
        response = client.post(uri, body:, headers: build_auth_header, content_type: "application/json")

        parse_upload_url(response)
      end

      # Complete image upload
      #
      # @param upload_url [URI::HTTPS] the upload URL from init_image_upload
      # @param image_file [Pathname] path to image file
      # @return [Hash] parsed response with image info (id, url, thumbnail)
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      def finish_image_upload(upload_url, image_file)
        image_file = Pathname(image_file) unless image_file.is_a?(Pathname)

        logger.info("Uploading image file", file: image_file.to_s)

        response = uploader.upload(upload_url, image_file)
        data = JSON.parse(response.body)

        logger.info("Image upload completed successfully", image_id: data["id"])
        data
      rescue JSON::ParserError => e
        raise HTTPError, "Invalid JSON response: #{e.message}"
      end

      # Edit mod's image list
      #
      # @param mod_name [String] the mod name
      # @param image_ids [Array<String>] array of image IDs (SHA1 hashes)
      # @return [void]
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      def edit_images(mod_name, image_ids)
        raise ArgumentError, "image_ids must be an array" unless image_ids.is_a?(Array)

        uri = URI.join(BASE_URL, "/api/v2/mods/images/edit")

        # Build form data
        form_data = {mod: mod_name, images: image_ids.join(",")}
        body = URI.encode_www_form(form_data)

        logger.info("Editing mod images", mod: mod_name, image_count: image_ids.size)
        client.post(uri, body:, headers: build_auth_header, content_type: "application/x-www-form-urlencoded")
        logger.info("Images updated successfully")
      end

      private def api_credential
        return @api_credential if defined?(@api_credential)

        @api_credential_mutex.synchronize do
          @api_credential ||= Application[:api_credential]
        end
      end

      private def build_auth_header
        {"Authorization" => "Bearer #{api_credential.api_key}"}
      end

      private def validate_metadata!(metadata, allowed_keys, context)
        return if metadata.empty?

        invalid_keys = metadata.keys.map(&:to_s) - allowed_keys
        return if invalid_keys.empty?

        raise ArgumentError,
          "Invalid metadata for #{context}: #{invalid_keys.join(", ")}. " \
          "Allowed keys: #{allowed_keys.join(", ")}"
      end

      private def parse_upload_url(response)
        data = JSON.parse(response.body)
        url_string = data["upload_url"] or raise HTTPError, "Missing upload_url in response"
        URI(url_string)
      rescue JSON::ParserError => e
        raise HTTPError, "Invalid JSON response: #{e.message}"
      end
    end
  end
end
