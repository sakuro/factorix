# frozen_string_literal: true

require "digest"
require "fileutils"
require "pathname"

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
      include Factorix::Import["logger"]

      # Maximum lifetime of lock files in seconds.
      # Lock files older than this will be considered stale and removed
      LOCK_FILE_LIFETIME = 3600 # 1 hour in seconds
      public_constant :LOCK_FILE_LIFETIME

      # Initialize a new file system cache storage.
      # Creates the cache directory if it doesn't exist
      #
      # @param cache_dir [Pathname, String] path to the cache directory
      # @param ttl [Integer, nil] time-to-live in seconds (nil for unlimited)
      # @param max_file_size [Integer, nil] maximum file size in bytes (nil for unlimited)
      def initialize(cache_dir, ttl: nil, max_file_size: nil, logger: nil)
        super(logger:)
        @cache_dir = Pathname(cache_dir)
        @ttl = ttl
        @max_file_size = max_file_size
        @cache_dir.mkpath
      end

      # Generate a cache key for the given URL string.
      # Uses SHA1 to create a unique, deterministic key
      #
      # @param url_string [String] URL string to generate key for
      # @return [String] cache key
      def key_for(url_string)
        Digest::SHA1.hexdigest(url_string)
      end

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
      # If the cache entry doesn't exist or is expired, returns false without modifying the output path
      #
      # @param key [String] cache key to fetch
      # @param output [Pathname] path to copy the cached file to
      # @return [Boolean] true if the cache entry was found and copied, false otherwise
      def fetch(key, output)
        path = cache_path_for(key)
        return false unless path.exist?
        return false if expired?(key)

        FileUtils.cp(path, output)
        true
      end

      # Read a cached file as a string.
      # If the cache entry doesn't exist or is expired, returns nil
      #
      # @param key [String] cache key to read
      # @param encoding [Encoding, String] encoding to use (default: ASCII-8BIT for binary)
      # @return [String, nil] cached content or nil if not found/expired
      def read(key, encoding: Encoding::ASCII_8BIT)
        path = cache_path_for(key)
        return nil unless path.exist?
        return nil if expired?(key)

        path.read(encoding:)
      end

      # Store a file in the cache.
      # Creates necessary subdirectories and copies the source file to the cache.
      # If the file size exceeds max_file_size, skips caching and returns false.
      #
      # @param key [String] cache key to store under
      # @param src [Pathname, String] path of the file to store
      # @return [Boolean] true if cached successfully, false if skipped due to size limit
      def store(key, src)
        file_size = File.size(src)

        # Skip caching if file exceeds size limit
        if @max_file_size && file_size > @max_file_size
          logger.warn "File size (#{file_size} bytes) exceeds cache limit (#{@max_file_size} bytes), skipping cache"
          return false
        end

        path = cache_path_for(key)
        path.dirname.mkpath
        FileUtils.cp(src, path)
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
        true
      end

      # Clear all cache entries.
      # Removes all files in the cache directory.
      #
      # @return [void]
      def clear
        @cache_dir.glob("**/*").each do |path|
          path.delete if path.file?
        end
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
            begin
              yield
            ensure
              lock.flock(File::LOCK_UN)
              begin
                lock_path.unlink
              rescue
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

      # Remove lock file if it exists and is older than LOCK_FILE_LIFETIME.
      # This prevents orphaned locks from blocking the cache indefinitely
      #
      # @param lock_path [Pathname] path to the lock file
      # @return [void]
      private def cleanup_stale_lock(lock_path)
        return unless lock_path.exist?
        return if (Time.now - lock_path.mtime) <= LOCK_FILE_LIFETIME

        begin
          lock_path.unlink
        rescue
          nil
        end
      end
    end
  end
end
