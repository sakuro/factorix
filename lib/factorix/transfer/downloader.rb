# frozen_string_literal: true

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
    # Reports progress to an optional listener.
    class Downloader
      attr_reader :logger
      attr_reader :cache
      attr_reader :client

      # Dependencies default to the Factorix.app composition root
      def initialize(logger: Factorix.app.logger, cache: Factorix.app.download_cache, client: Factorix.app.download_http_client)
        @logger = logger
        @cache = cache
        @client = client
      end

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
      # @param listener [Progress::DownloadHandler, nil] optional progress listener
      # @return [void]
      # @raise [URLError] if the URL is not HTTPS
      # @raise [HTTPClientError] for 4xx HTTP errors
      # @raise [HTTPServerError] for 5xx HTTP errors
      # @raise [DigestMismatchError] if SHA1 verification fails
      def download(url, output, expected_sha1: nil, listener: nil)
        unless url.is_a?(URI::HTTPS)
          logger.error "Invalid URL: must be HTTPS"
          raise URLError, "URL must be HTTPS"
        end

        logger.info("Starting download", output: output.to_s)
        cache_key = strip_query(url)

        case try_cache_hit(cache_key, output, expected_sha1:, listener:)
        when :hit
          return
        when :miss
          logger.debug("Cache miss, downloading", output: output.to_s)
        when :corrupted
          logger.debug("Re-downloading after cache invalidation", output: output.to_s)
        else
          raise RuntimeError, "Unexpected cache state"
        end

        cache.with_lock(cache_key) do
          return if try_cache_hit(cache_key, output, expected_sha1:, listener:) == :hit

          with_temporary_file do |temp_file|
            download_file_with_progress(url, temp_file, listener)
            verify_sha1(temp_file, expected_sha1) if expected_sha1
            cache.store(cache_key, temp_file)
            cache.write_to(cache_key, output)
          end
        end
      end

      # Download file with progress tracking
      #
      # @param url [URI::HTTPS] URL to download from
      # @param output [Pathname] path to save the downloaded file
      # @param listener [Progress::DownloadHandler, nil] optional progress listener
      # @return [void]
      private def download_file_with_progress(url, output, listener)
        current_size = 0

        client.get(url) do |response|
          content_length = response["Content-Length"]
          total_size = content_length ? Integer(content_length, 10) : nil

          listener&.on_started(total: total_size)

          output.open("wb") do |file|
            response.read_body do |chunk|
              file.write(chunk)
              current_size += chunk.bytesize
              listener&.on_progress(current: current_size)
            end
          end
        end

        listener&.on_completed
      end

      # Attempt to retrieve file from cache with SHA1 verification.
      #
      # If the cached file exists but fails SHA1 verification, the cache entry
      # is invalidated and :corrupted is returned to trigger re-download.
      #
      # @param cache_key [String] logical cache key (URL string)
      # @param output [Pathname] path to save the cached file
      # @param expected_sha1 [String, nil] expected SHA1 digest for verification (optional)
      # @param listener [Progress::DownloadHandler, nil] optional progress listener
      # @return [Symbol] :hit if cache hit with valid SHA1, :miss if not cached, :corrupted if SHA1 mismatch
      private def try_cache_hit(cache_key, output, expected_sha1:, listener: nil)
        return :miss unless cache.write_to(cache_key, output)

        logger.info("Cache hit", output: output.to_s)
        verify_sha1(output, expected_sha1) if expected_sha1
        listener&.on_cache_hit(total: cache.size(cache_key))
        :hit
      rescue DigestMismatchError => e
        logger.warn("Cache corrupted, invalidating", output: output.to_s, error: e.message)
        cache.delete(cache_key)
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

      # Strip query parameters from a URI to create a safe cache key.
      # This prevents sensitive data (e.g., authentication tokens) from being
      # stored in cache metadata.
      #
      # @param uri [URI] the URI to strip
      # @return [String] URI string without query parameters
      private def strip_query(uri) = uri.dup.tap {|u| u.query = nil }.to_s

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
