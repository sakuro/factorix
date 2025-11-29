# frozen_string_literal: true

require "dry/events"
require "pathname"
require "tmpdir"
require "uri"

module Factorix
  module Transfer
    # File downloader with caching and progress tracking
    #
    # Downloads files from HTTPS URLs with automatic caching.
    # Uses file locking to prevent concurrent downloads of the same file.
    # HTTP redirects are handled automatically by the HTTP layer.
    # Publishes progress events during download.
    class Downloader
      # @!parse
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      #   # @return [Cache::FileSystem]
      #   attr_reader :cache
      #   # @return [HTTP::Client]
      #   attr_reader :client
      include Import[:logger, cache: :download_cache, client: :download_http_client]
      include Dry::Events::Publisher[:downloader]

      register_event("download.started")
      register_event("download.progress")
      register_event("download.completed")
      register_event("cache.hit")
      register_event("cache.miss")

      # Download a file from the given URL with caching support.
      #
      # If the file exists in cache, it will be copied from cache instead of downloading.
      # If the cached file fails SHA1 verification, it will be invalidated and re-downloaded.
      # If multiple processes attempt to download the same file, only one will download
      # while others wait for the download to complete.
      # HTTP redirects are followed automatically by the HTTP layer.
      #
      # @param url [URI::HTTPS] URL to download from
      # @param output [Pathname] path to save the downloaded file
      # @param expected_sha1 [String, nil] expected SHA1 digest for verification (optional)
      # @return [void]
      # @raise [ArgumentError] if the URL is not HTTPS
      # @raise [HTTPClientError] for 4xx HTTP errors
      # @raise [HTTPServerError] for 5xx HTTP errors
      # @raise [DigestMismatchError] if SHA1 verification fails
      def download(url, output, expected_sha1: nil)
        unless url.is_a?(URI::HTTPS)
          logger.error "Invalid URL: must be HTTPS"
          raise ArgumentError, "URL must be HTTPS"
        end

        masked_url = mask_credentials(url)
        logger.info("Starting download", url: masked_url, output: output.to_s)
        key = cache.key_for(url.to_s)

        case try_cache_hit(key, output, expected_sha1:, masked_url:)
        when :hit
          return
        when :miss
          logger.debug("Cache miss, downloading", url: masked_url)
          publish("cache.miss", url: masked_url)
        when :corrupted
          logger.debug("Re-downloading after cache invalidation", url: masked_url)
          publish("cache.miss", url: masked_url)
        else
          raise RuntimeError, "Unexpected cache state"
        end

        cache.with_lock(key) do
          return if try_cache_hit(key, output, expected_sha1:, masked_url:) == :hit

          with_temporary_file do |temp_file|
            download_file_with_progress(url, temp_file)
            verify_sha1(temp_file, expected_sha1) if expected_sha1
            cache.store(key, temp_file)
            cache.fetch(key, output)
          end
        end
      end

      # Download file with progress tracking
      #
      # @param url [URI::HTTPS] URL to download from
      # @param output [Pathname] path to save the downloaded file
      # @return [void]
      private def download_file_with_progress(url, output)
        total_size = nil
        current_size = 0

        client.get(url) do |response|
          content_length = response["Content-Length"]
          total_size = content_length ? Integer(content_length, 10) : nil

          publish("download.started", total_size:)

          output.open("wb") do |file|
            response.read_body do |chunk|
              file.write(chunk)
              current_size += chunk.bytesize
              publish("download.progress", current_size:, total_size:)
            end
          end
        end

        publish("download.completed", total_size: current_size)
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

      # Attempt to retrieve file from cache with SHA1 verification.
      #
      # If the cached file exists but fails SHA1 verification, the cache entry
      # is invalidated and :corrupted is returned to trigger re-download.
      #
      # @param key [String] cache key
      # @param output [Pathname] path to save the cached file
      # @param expected_sha1 [String, nil] expected SHA1 digest for verification (optional)
      # @param masked_url [String] URL with credentials masked (for logging)
      # @return [Symbol] :hit if cache hit with valid SHA1, :miss if not cached, :corrupted if SHA1 mismatch
      private def try_cache_hit(key, output, expected_sha1:, masked_url:)
        return :miss unless cache.fetch(key, output)

        logger.info("Cache hit", url: masked_url)
        verify_sha1(output, expected_sha1) if expected_sha1
        total_size = cache.size(key)
        publish("cache.hit", url: masked_url, output: output.to_s, total_size:)
        :hit
      rescue DigestMismatchError => e
        logger.warn("Cache corrupted, invalidating", url: masked_url, error: e.message)
        cache.delete(key)
        :corrupted
      end

      # Verify SHA1 digest of a file
      #
      # @param file [Pathname] file to verify
      # @param expected_sha1 [String] expected SHA1 digest
      # @return [void]
      # @raise [DigestMismatchError] if digest does not match
      private def verify_sha1(file, expected_sha1)
        actual_sha1 = Digest(:SHA1).file(file).hexdigest
        return if actual_sha1 == expected_sha1

        logger.error("SHA1 digest mismatch", expected: expected_sha1, actual: actual_sha1)
        raise DigestMismatchError, "SHA1 mismatch: expected #{expected_sha1}, got #{actual_sha1}"
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
