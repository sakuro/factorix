# frozen_string_literal: true

require "uri"

module Factorix
  module API
    # API client for downloading mod files with service authentication
    #
    # Requires username and token authentication via ServiceCredential.
    class MODDownloadAPI
      # NOTE: service_credential is NOT imported to avoid early evaluation errors
      # when FACTORIO_USERNAME/FACTORIO_TOKEN environment variables are not set.
      # It's resolved lazily via reader method instead.
      # @!parse
      #   # @return [Transfer::Downloader]
      #   attr_reader :downloader
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      include Import[:downloader, :logger]

      BASE_URL = "https://mods.factorio.com"
      private_constant :BASE_URL

      # Initialize with thread-safe credential loading
      #
      # @param args [Hash] dependency injection arguments
      def initialize(...)
        super
        @service_credential_mutex = Mutex.new
      end

      # Download a mod file to the specified output path
      #
      # @param download_url [String] relative download URL from API response (e.g., "/download/mod-name/...")
      # @param output [Pathname] output file path
      # @return [void]
      # @raise [ArgumentError] if download_url is not a relative path starting with "/"
      def download(download_url, output)
        unless download_url.start_with?("/")
          logger.error("Invalid download_url", url: download_url)
          raise ArgumentError, "download_url must be a relative path starting with '/'"
        end

        uri = build_download_uri(download_url)
        downloader.download(uri, output)
      end

      private def service_credential
        return @service_credential if defined?(@service_credential)

        @service_credential_mutex.synchronize do
          @service_credential ||= Application[:service_credential]
        end
      end

      private def build_download_uri(download_url)
        uri = URI.join(BASE_URL, download_url)
        params = {
          username: service_credential.username,
          token: service_credential.token
        }
        uri.query = URI.encode_www_form(params)
        uri
      end
    end
  end
end
