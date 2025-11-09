# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "uri"

module Factorix
  module Transfer
    # File downloader with caching support
    #
    # Downloads files from HTTPS URLs with automatic caching.
    # Uses file locking to prevent concurrent downloads of the same file.
    # HTTP redirects are handled automatically by the HTTP layer.
    class Downloader
      include Factorix::Import["download_cache", "http"]

      # Download a file from the given URL with caching support.
      #
      # If the file exists in cache, it will be copied from cache instead of downloading.
      # If multiple processes attempt to download the same file, only one will download
      # while others wait for the download to complete.
      # HTTP redirects are followed automatically by the HTTP layer.
      #
      # @param url [URI::HTTPS] URL to download from
      # @param output [Pathname] path to save the downloaded file
      # @return [void]
      # @raise [ArgumentError] if the URL is not HTTPS
      # @raise [HTTPClientError] for 4xx HTTP errors
      # @raise [HTTPServerError] for 5xx HTTP errors
      def download(url, output)
        raise ArgumentError, "URL must be HTTPS" unless url.is_a?(URI::HTTPS)

        key = download_cache.key_for(url.to_s)

        return if download_cache.fetch(key, output)

        download_cache.with_lock(key) do
          return if download_cache.fetch(key, output)

          with_temporary_file do |temp_file|
            # HTTP layer handles redirects automatically
            http.download(url, temp_file)

            # Download completed successfully - store in cache
            download_cache.store(key, temp_file)
            download_cache.fetch(key, output)
          end
        end
      end

      # Create a temporary file for downloading, ensuring cleanup after use.
      #
      # @yield [Pathname] the temporary file path
      # @return [void]
      private def with_temporary_file
        dir = Pathname(Dir.mktmpdir("factorix"))
        temp_file = dir.join("download")
        temp_file.binwrite("")
        yield temp_file
      ensure
        temp_file&.unlink if temp_file&.exist?
        dir&.rmdir if dir&.exist?
      end
    end
  end
end
