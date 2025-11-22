# frozen_string_literal: true

require "digest"
require "fileutils"
require "pathname"
require "zlib"

module Factorix
  module Cache
    # File system based cache storage implementation.
    #
    # Uses a two-level directory structure to store cached files,
    # with file locking to handle concurrent access and TTL support
    # for cache expiration.
    class FileSystem
      # @!parse
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      include Import[:logger]

      # Maximum lifetime of lock files in seconds.
      # Lock files older than this will be considered stale and removed
      LOCK_FILE_LIFETIME = 3600 # 1 hour in seconds
      public_constant :LOCK_FILE_LIFETIME

      # zlib CMF byte indicating DEFLATE compression with default window size.
      # Used to detect if cached data is zlib-compressed
      ZLIB_CMF_BYTE = 0x78
      private_constant :ZLIB_CMF_BYTE

      # Initialize a new file system cache storage.
      # Creates the cache directory if it doesn't exist
      #
      # @param cache_dir [Pathname] path to the cache directory
      # @param ttl [Integer, nil] time-to-live in seconds (nil for unlimited)
      # @param max_file_size [Integer, nil] maximum file size in bytes (nil for unlimited)
      # @param compression_threshold [Integer, nil] compress data larger than this size in bytes
      #   (nil: no compression, 0: always compress, N: compress if >= N bytes)
      def initialize(cache_dir, ttl: nil, max_file_size: nil, compression_threshold: nil, logger: nil)
        super(logger:)
        @cache_dir = cache_dir
        @ttl = ttl
        @max_file_size = max_file_size
        @compression_threshold = compression_threshold
        @cache_dir.mkpath
        logger.info("Initializing cache", dir: @cache_dir.to_s, ttl: @ttl, max_size: @max_file_size, compression_threshold: @compression_threshold)
      end

      # Generate a cache key for the given URL string.
      # Uses SHA1 to create a unique, deterministic key
      #
      # @param url_string [String] URL string to generate key for
      # @return [String] cache key
      # Use Digest(:SHA1) instead of Digest::SHA1 for thread-safety (Ruby 2.2+)
      def key_for(url_string) = Digest(:SHA1).hexdigest(url_string)

      # Check if a cache entry exists and is not expired.
      # A cache entry is considered to exist if its file exists and is not expired
      #
      # @param key [String] cache key to check
      # @return [Boolean] true if the cache entry exists and is valid, false otherwise
      def exist?(key)
        return false unless cache_path_for(key).exist?
        return true if @ttl.nil?

        !expired?(key)
      end

      # Fetch a cached file and copy it to the output path.
      # If the cache entry doesn't exist or is expired, returns false without modifying the output path.
      # Automatically decompresses zlib-compressed cache entries.
      #
      # @param key [String] cache key to fetch
      # @param output [Pathname] path to copy the cached file to
      # @return [Boolean] true if the cache entry was found and copied, false otherwise
      def fetch(key, output)
        path = cache_path_for(key)
        unless path.exist?
          logger.debug("Cache miss", key:)
          return false
        end

        if expired?(key)
          logger.debug("Cache expired", key:, age_seconds: age(key))
          return false
        end

        data = path.binread
        if zlib_compressed?(data)
          data = Zlib.inflate(data)
          output.binwrite(data)
        else
          FileUtils.cp(path, output)
        end
        logger.debug("Cache hit", key:)
        true
      end

      # Read a cached file as a string.
      # If the cache entry doesn't exist or is expired, returns nil.
      # Automatically decompresses zlib-compressed cache entries.
      #
      # @param key [String] cache key to read
      # @param encoding [Encoding, String] encoding to use (default: ASCII-8BIT for binary)
      # @return [String, nil] cached content or nil if not found/expired
      def read(key, encoding: Encoding::ASCII_8BIT)
        path = cache_path_for(key)
        return nil unless path.exist?
        return nil if expired?(key)

        data = path.binread
        data = Zlib.inflate(data) if zlib_compressed?(data)
        data.force_encoding(encoding)
      end

      # Store a file in the cache.
      # Creates necessary subdirectories and stores the file in the cache.
      # Optionally compresses data based on compression_threshold setting.
      # If the (possibly compressed) size exceeds max_file_size, skips caching and returns false.
      #
      # @param key [String] cache key to store under
      # @param src [Pathname] path of the file to store
      # @return [Boolean] true if cached successfully, false if skipped due to size limit
      def store(key, src)
        data = src.binread
        original_size = data.bytesize

        # Compress if enabled and data meets threshold
        if should_compress?(original_size)
          data = Zlib.deflate(data)
          logger.debug("Compressed data", original_size:, compressed_size: data.bytesize)
        end

        # Skip caching if (compressed) size exceeds limit
        if @max_file_size && data.bytesize > @max_file_size
          logger.warn("File size exceeds cache limit, skipping", size_bytes: data.bytesize, limit_bytes: @max_file_size)
          return false
        end

        path = cache_path_for(key)
        path.dirname.mkpath
        path.binwrite(data)
        logger.debug("Stored in cache", key:, size_bytes: data.bytesize)
        true
      end

      # Delete a specific cache entry.
      #
      # @param key [String] cache key to delete
      # @return [Boolean] true if the entry was deleted, false if it didn't exist
      def delete(key)
        path = cache_path_for(key)
        return false unless path.exist?

        path.delete
        logger.debug("Deleted from cache", key:)
        true
      end

      # Clear all cache entries.
      # Removes all files in the cache directory.
      #
      # @return [void]
      def clear
        logger.info("Clearing cache directory", dir: @cache_dir.to_s)
        count = 0
        @cache_dir.glob("**/*").each do |path|
          if path.file?
            path.delete
            count += 1
          end
        end
        logger.info("Cache cleared", files_removed: count)
      end

      # Get the age of a cache entry in seconds.
      # Returns nil if the entry doesn't exist.
      #
      # @param key [String] cache key
      # @return [Float, nil] age in seconds, or nil if entry doesn't exist
      def age(key)
        path = cache_path_for(key)
        return nil unless path.exist?

        Time.now - path.mtime
      end

      # Check if a cache entry has expired based on TTL.
      # Returns false if TTL is not set (unlimited) or if entry doesn't exist.
      #
      # @param key [String] cache key
      # @return [Boolean] true if expired, false otherwise
      def expired?(key)
        return false if @ttl.nil?

        age_seconds = age(key)
        return false if age_seconds.nil?

        age_seconds > @ttl
      end

      # Get the size of a cached file in bytes.
      # Returns nil if the entry doesn't exist or is expired.
      #
      # @param key [String] cache key
      # @return [Integer, nil] file size in bytes, or nil if entry doesn't exist/expired
      def size(key)
        path = cache_path_for(key)
        return nil unless path.exist?
        return nil if expired?(key)

        path.size
      end

      # Executes the given block with a file lock.
      # Uses flock for process-safe file locking and automatically removes stale locks
      #
      # @param key [String] cache key to lock
      # @yield Executes the block with exclusive file lock
      # @return [void]
      def with_lock(key)
        lock_path = lock_path_for(key)
        cleanup_stale_lock(lock_path)

        lock_path.dirname.mkpath
        lock_path.open(File::RDWR | File::CREAT) do |lock|
          if lock.flock(File::LOCK_EX)
            logger.debug("Acquired lock", key:)
            begin
              yield
            ensure
              lock.flock(File::LOCK_UN)
              logger.debug("Released lock", key:)
              begin
                lock_path.unlink
              rescue => e
                logger.debug("Failed to remove lock file", path: lock_path.to_s, error: e.message)
                nil
              end
            end
          end
        end
      end

      # Get the cache file path for the given key.
      # Uses a two-level directory structure to avoid too many files in one directory
      #
      # @param key [String] cache key
      # @return [Pathname] path to the cache file
      private def cache_path_for(key)
        prefix = key[0, 2]
        @cache_dir.join(prefix, key[2..])
      end

      # Get the lock file path for the given key.
      # Lock files are stored alongside cache files with a .lock extension
      #
      # @param key [String] cache key
      # @return [Pathname] path to the lock file
      private def lock_path_for(key)
        cache_path_for(key).sub_ext(".lock")
      end

      # Check if data should be compressed based on compression_threshold setting.
      #
      # @param size [Integer] data size in bytes
      # @return [Boolean] true if data should be compressed
      private def should_compress?(size)
        return false if @compression_threshold.nil?

        size >= @compression_threshold
      end

      # Check if data is zlib-compressed by examining the CMF and FLG bytes.
      # zlib header consists of CMF (byte 0) and FLG (byte 1) where
      # (CMF * 256 + FLG) % 31 must equal 0.
      #
      # @param data [String] binary data to check
      # @return [Boolean] true if data appears to be zlib-compressed
      private def zlib_compressed?(data)
        return false if data.bytesize < 2

        cmf = data.getbyte(0)
        flg = data.getbyte(1)
        cmf == ZLIB_CMF_BYTE && ((cmf << 8) | flg) % 31 == 0
      end

      # Remove lock file if it exists and is older than LOCK_FILE_LIFETIME.
      # This prevents orphaned locks from blocking the cache indefinitely
      #
      # @param lock_path [Pathname] path to the lock file
      # @return [void]
      private def cleanup_stale_lock(lock_path)
        return unless lock_path.exist?

        age = Time.now - lock_path.mtime
        return if age <= LOCK_FILE_LIFETIME

        begin
          lock_path.unlink
          logger.warn("Removed stale lock", path: lock_path.to_s, age_seconds: age)
        rescue => e
          logger.debug("Failed to remove stale lock", path: lock_path.to_s, error: e.message)
          nil
        end
      end
    end
  end
end
