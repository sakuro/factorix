# frozen_string_literal: true

require "uri"

module Factorix
  module Transfer
    # File uploader with automatic retry
    #
    # Uploads files to given URLs using HTTP multipart/form-data.
    # Uses Transfer::HTTP for the actual upload with event-driven progress notification.
    class Uploader
      # @!parse
      #   # @return [HTTP]
      #   attr_reader :http
      include Factorix::Import["http"]

      # Upload a file to the given URL
      #
      # @param url [URI::HTTPS, String] URL to upload to (HTTPS only)
      # @param file_path [Pathname, String] path to the file to upload
      # @param field_name [String] form field name for the file (default: "file")
      # @return [void]
      # @raise [ArgumentError] if the URL is not HTTPS
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      # @raise [HTTPError] for other HTTP errors
      def upload(url, file_path, field_name: "file")
        url = URI(url) if url.is_a?(String)
        raise ArgumentError, "URL must be HTTPS" unless url.is_a?(URI::HTTPS)

        file_path = Pathname(file_path)

        http.upload(url, file_path, field_name:)
      end
    end
  end
end
