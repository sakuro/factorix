# frozen_string_literal: true

require "pathname"
require "tmpdir"

module Factorix
  # Class responsible for file downloads with caching support
  class Downloader
    # Initialize a new downloader with cache storage and HTTP client
    #
    # @param cache_storage [Cache::FileSystem] cache storage
    # @param http_client [HTTPClient] HTTP client
    def initialize(
      cache_storage: Cache::FileSystem.new(Runtime.runtime.cache_dir),
      http_client: HTTPClient.new
    )
      @cache_storage = cache_storage
      @http_client = http_client
    end

    # Download a file from the given URL with caching support.
    #
    # If the file exists in cache, it will be copied from cache instead of downloading.
    # If multiple processes attempt to download the same file, only one will download
    # while others wait for the download to complete
    #
    # @param url [URI::HTTP] URL to download from
    # @param output [String, Pathname] path to save the downloaded file
    # @return [void]
    # @raise [ArgumentError] if the URL is not HTTP(S)
    # @raise [Factorix::DownloadError] if the download fails
    def download(url, output)
      raise ArgumentError, "URL must be HTTP or HTTPS" unless url.is_a?(URI::HTTP)

      output = Pathname(output)
      key = @cache_storage.key_for(url.to_s)

      return if @cache_storage.fetch(key, output)

      @cache_storage.with_lock(key) do
        return if @cache_storage.fetch(key, output)

        with_temporary_file do |temp_file|
          @http_client.download(url, temp_file)
          @cache_storage.store(key, temp_file)
          @cache_storage.fetch(key, output)
        end
      end
    end

    # Create a temporary file for downloading, ensuring cleanup after use.
    # The temporary file is created in a unique directory to avoid conflicts
    #
    # @yield [Pathname] the temporary file path
    # @return [void]
    private def with_temporary_file
      dir = Pathname(Dir.mktmpdir("factorix"))
      temp_file = dir.join("download")
      temp_file.binwrite("") # Create an empty file
      yield temp_file
    ensure
      if temp_file&.exist?
        temp_file.unlink
      end
      if dir&.exist?
        dir.rmdir
      end
    end
  end
end
