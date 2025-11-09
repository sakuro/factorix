# frozen_string_literal: true

require "uri"

module Factorix
  module API
    # API client for downloading mod files with service authentication
    #
    # Requires username and token authentication via ServiceCredential.
    class MODDownloadAPI
      include Factorix::Import["service_credential", "downloader"]

      BASE_URL = "https://mods.factorio.com"
      private_constant :BASE_URL

      # Download a mod file to the specified output path
      #
      # @param download_url [String] relative download URL from API response (e.g., "/download/mod-name/...")
      # @param output [Pathname] output file path
      # @return [void]
      # @raise [ArgumentError] if download_url is not a relative path starting with "/"
      def download(download_url, output)
        raise ArgumentError, "download_url must be a relative path starting with '/'" unless download_url.start_with?("/")

        uri = build_download_uri(download_url)
        downloader.download(uri, output)
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
