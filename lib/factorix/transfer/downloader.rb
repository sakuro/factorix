# frozen_string_literal: true

require "dry/monads"
require "pathname"
require "tmpdir"
require "uri"

module Factorix
  module Transfer
    # File downloader with caching support
    #
    # Downloads files from HTTPS URLs with automatic caching.
    # Uses file locking to prevent concurrent downloads of the same file.
    # Automatically follows HTTP redirects up to a maximum depth.
    class Downloader
      include Factorix::Import["download_cache", "http"]
      include Dry::Monads[:result]

      # Maximum number of redirects to follow
      MAX_REDIRECTS = 10
      private_constant :MAX_REDIRECTS

      # Download a file from the given URL with caching support.
      #
      # If the file exists in cache, it will be copied from cache instead of downloading.
      # If multiple processes attempt to download the same file, only one will download
      # while others wait for the download to complete.
      # Automatically follows HTTP redirects up to MAX_REDIRECTS.
      #
      # @param url [URI::HTTPS] URL to download from
      # @param output [Pathname] path to save the downloaded file
      # @param redirect_count [Integer] internal counter for redirect depth
      # @return [void]
      # @raise [ArgumentError] if the URL is not HTTPS or too many redirects
      def download(url, output, redirect_count: 0)
        raise ArgumentError, "URL must be HTTPS" unless url.is_a?(URI::HTTPS)
        raise ArgumentError, "Too many redirects (#{redirect_count})" if redirect_count > MAX_REDIRECTS

        key = download_cache.key_for(url.to_s)

        return if download_cache.fetch(key, output)

        download_cache.with_lock(key) do
          return if download_cache.fetch(key, output)

          with_temporary_file do |temp_file|
            result = http.download(url, temp_file)

            case result
            in Success(redirect: location)
              # Follow redirect to new location
              redirect_url = URI(location)
              download(redirect_url, output, redirect_count: redirect_count + 1)

            in Success(:ok)
              # Download completed successfully - store in cache
              download_cache.store(key, temp_file)
              download_cache.fetch(key, output)

            in Failure(error)
              # HTTP error - re-raise as exception
              raise error
            end
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
