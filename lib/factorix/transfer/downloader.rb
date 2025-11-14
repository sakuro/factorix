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
      # @!parse
      #   # @return [Cache::FileSystem]
      #   attr_reader :download_cache
      #   # @return [HTTP]
      #   attr_reader :http
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      include Factorix::Import["download_cache", "http", "logger"]

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
        unless url.is_a?(URI::HTTPS)
          logger.error "Invalid URL: must be HTTPS"
          raise ArgumentError, "URL must be HTTPS"
        end

        masked_url = mask_credentials(url)
        logger.info("Starting download", url: masked_url, output: output.to_s)
        key = download_cache.key_for(url.to_s)

        if download_cache.fetch(key, output)
          logger.info("Cache hit", url: masked_url)
          total_size = download_cache.size(key)
          http.publish("cache.hit", url: masked_url, output: output.to_s, total_size:)
          return
        end

        logger.debug("Cache miss, downloading", url: masked_url)
        http.publish("cache.miss", url: masked_url)
        download_cache.with_lock(key) do
          if download_cache.fetch(key, output)
            logger.info("Cache hit", url: masked_url)
            total_size = download_cache.size(key)
            http.publish("cache.hit", url: masked_url, output: output.to_s, total_size:)
            return
          end

          with_temporary_file do |temp_file|
            # HTTP layer handles redirects automatically
            http.download(url, temp_file)

            # Download completed successfully - store in cache
            download_cache.store(key, temp_file)
            download_cache.fetch(key, output)
          end
        end
      end

      private def mask_credentials(url)
        return url.to_s unless url.query

        masked_url = url.dup
        params = URI.decode_www_form(masked_url.query).to_h
        params["username"] = "*****" if params.key?("username")
        params["token"] = "*****" if params.key?("token")
        masked_url.query = URI.encode_www_form(params)
        masked_url.to_s
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
