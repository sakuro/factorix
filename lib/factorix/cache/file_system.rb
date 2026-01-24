# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "pathname"
require "zlib"

module Factorix
  module Cache
    # File system based cache storage implementation.
    #
    # Uses a two-level directory structure to store cached files,
    # with file locking to handle concurrent access and TTL support
    # for cache expiration.
    #
    # Cache entries consist of:
    # - Data file: the cached content (optionally compressed)
    # - Metadata file (.metadata): JSON containing the logical key
    # - Lock file (.lock): used for concurrent access control
    class FileSystem < Base
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
      # Creates the cache directory if it doesn't exist.
      # Cache directory is auto-calculated as: factorix_cache_dir / cache_type
      #
      # @param cache_type [Symbol] cache type for directory name (e.g., :api, :download)
      # @param max_file_size [Integer, nil] maximum file size in bytes (nil for unlimited)
      # @param compression_threshold [Integer, nil] compress data larger than this size in bytes
      #   (nil: no compression, 0: always compress, N: compress if >= N bytes)
      # @param ttl [Integer, nil] time-to-live in seconds (nil for unlimited)
      def initialize(cache_type:, max_file_size: nil, compression_threshold: nil, **)
        super(**)
        @cache_dir = Container[:runtime].factorix_cache_dir / cache_type.to_s
        @max_file_size = max_file_size
        @compression_threshold = compression_threshold
        @cache_dir.mkpath
        logger.info("Initializing cache", root: @cache_dir.to_s, ttl: @ttl, max_size: @max_file_size, compression_threshold: @compression_threshold)
      end

      # Check if a cache entry exists and is not expired.
      # A cache entry is considered to exist if its file exists and is not expired
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if the cache entry exists and is valid, false otherwise
      def exist?(key)
        internal_key = storage_key_for(key)
        return false unless cache_path_for(internal_key).exist?
        return true if @ttl.nil?

        !expired?(key)
      end

      # Write cached content to a file.
      # If the cache entry doesn't exist or is expired, returns false without modifying the output path.
      # Automatically decompresses zlib-compressed cache entries.
      #
      # @param key [String] logical cache key
      # @param output [Pathname] path to write the cached content to
      # @return [Boolean] true if written successfully, false if not found/expired
      def write_to(key, output)
        internal_key = storage_key_for(key)
        path = cache_path_for(internal_key)
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

      # Read a cached file as a binary string.
      # If the cache entry doesn't exist or is expired, returns nil.
      # Automatically decompresses zlib-compressed cache entries.
      #
      # @param key [String] logical cache key
      # @return [String, nil] cached content or nil if not found/expired
      def read(key)
        internal_key = storage_key_for(key)
        path = cache_path_for(internal_key)
        return nil unless path.exist?
        return nil if expired?(key)

        data = path.binread
        data = Zlib.inflate(data) if zlib_compressed?(data)
        data
      end

      # Store a file in the cache.
      # Creates necessary subdirectories and stores the file in the cache.
      # Optionally compresses data based on compression_threshold setting.
      # If the (possibly compressed) size exceeds max_file_size, skips caching and returns false.
      #
      # @param key [String] logical cache key
      # @param src [Pathname] path of the file to store
      # @return [Boolean] true if cached successfully, false if skipped due to size limit
      def store(key, src)
        data = src.binread
        original_size = data.bytesize

        if should_compress?(original_size)
          data = Zlib.deflate(data)
          logger.debug("Compressed data", original_size:, compressed_size: data.bytesize)
        end

        if @max_file_size && data.bytesize > @max_file_size
          logger.warn("File size exceeds cache limit, skipping", size_bytes: data.bytesize, limit_bytes: @max_file_size)
          return false
        end

        internal_key = storage_key_for(key)
        path = cache_path_for(internal_key)
        metadata_path = metadata_path_for(internal_key)

        path.dirname.mkpath
        path.binwrite(data)
        metadata_path.write(JSON.generate({logical_key: key}))
        logger.debug("Stored in cache", key:, size_bytes: data.bytesize)
        true
      end

      # Delete a specific cache entry.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if the entry was deleted, false if it didn't exist
      def delete(key)
        internal_key = storage_key_for(key)
        path = cache_path_for(internal_key)
        metadata_path = metadata_path_for(internal_key)

        return false unless path.exist?

        path.delete
        metadata_path.delete if metadata_path.exist?
        logger.debug("Deleted from cache", key:)
        true
      end

      # Clear all cache entries.
      # Removes all files in the cache directory.
      #
      # @return [void]
      def clear
        logger.info("Clearing cache directory", root: @cache_dir.to_s)
        count = 0
        @cache_dir.glob("**/*").each do |path|
          next unless path.file?
          next if path.extname == ".lock"

          path.delete
          count += 1
        end
        logger.info("Cache cleared", files_removed: count)
      end

      # Get the age of a cache entry in seconds.
      # Returns nil if the entry doesn't exist.
      #
      # @param key [String] logical cache key
      # @return [Float, nil] age in seconds, or nil if entry doesn't exist
      def age(key)
        internal_key = storage_key_for(key)
        path = cache_path_for(internal_key)
        return nil unless path.exist?

        Time.now - path.mtime
      end

      # Check if a cache entry has expired based on TTL.
      # Returns false if TTL is not set (unlimited) or if entry doesn't exist.
      #
      # @param key [String] logical cache key
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
      # @param key [String] logical cache key
      # @return [Integer, nil] file size in bytes, or nil if entry doesn't exist/expired
      def size(key)
        internal_key = storage_key_for(key)
        path = cache_path_for(internal_key)
        return nil unless path.exist?
        return nil if expired?(key)

        path.size
      end

      # Executes the given block with a file lock.
      # Uses flock for process-safe file locking and automatically removes stale locks.
      #
      # @param key [String] logical cache key
      # @yield Executes the block with exclusive file lock
      # @return [void]
      def with_lock(key)
        internal_key = storage_key_for(key)
        lock_path = lock_path_for(internal_key)
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

      # Enumerate cache entries.
      #
      # Yields [key, entry] pairs similar to Hash#each.
      # Skips entries without metadata files (legacy entries).
      #
      # @yield [key, entry] logical key and Entry object
      # @yieldparam key [String] logical cache key
      # @yieldparam entry [Entry] cache entry metadata
      # @return [Enumerator] if no block given
      def each
        return enum_for(__method__) unless block_given?

        @cache_dir.glob("**/*").each do |path|
          next unless path.file?
          next if path.extname == ".metadata" || path.extname == ".lock"

          metadata_path = Pathname("#{path}.metadata")
          next unless metadata_path.exist?

          logical_key = JSON.parse(metadata_path.read)["logical_key"]
          age = Time.now - path.mtime
          entry = Entry[
            size: path.size,
            age:,
            expired: @ttl ? age > @ttl : false
          ]

          yield logical_key, entry
        end
      end

      # Return backend-specific information.
      #
      # @return [Hash] backend configuration and status
      def backend_info
        {
          type: "file_system",
          directory: @cache_dir.to_s,
          max_file_size: @max_file_size,
          compression_threshold: @compression_threshold,
          stale_locks: count_stale_locks
        }
      end

      # Generate a storage key for the given logical key.
      # Uses SHA1 to create a unique, deterministic key.
      # Use Digest(:SHA1) instead of Digest::SHA1 for thread-safety (Ruby 2.2+)
      #
      # @param logical_key [String] logical key to generate storage key for
      # @return [String] storage key (SHA1 hash)
      private def storage_key_for(logical_key) = Digest(:SHA1).hexdigest(logical_key)

      # Get the cache file path for the given internal key.
      # Uses a two-level directory structure to avoid too many files in one directory
      #
      # @param internal_key [String] internal storage key
      # @return [Pathname] path to the cache file
      private def cache_path_for(internal_key)
        prefix = internal_key[0, 2]
        @cache_dir.join(prefix, internal_key[2..])
      end

      # Get the metadata file path for the given internal key.
      #
      # @param internal_key [String] internal storage key
      # @return [Pathname] path to the metadata file
      private def metadata_path_for(internal_key)
        Pathname("#{cache_path_for(internal_key)}.metadata")
      end

      # Get the lock file path for the given internal key.
      # Lock files are stored alongside cache files with a .lock extension
      #
      # @param internal_key [String] internal storage key
      # @return [Pathname] path to the lock file
      private def lock_path_for(internal_key)
        cache_path_for(internal_key).sub_ext(".lock")
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

      # Count stale lock files in the cache directory.
      #
      # @return [Integer] number of stale lock files
      private def count_stale_locks
        cutoff = Time.now - LOCK_FILE_LIFETIME
        @cache_dir.glob("**/*.lock").count {|path| path.mtime < cutoff }
      end
    end
  end
end
