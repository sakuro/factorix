# frozen_string_literal: true

require "digest"
require "fileutils"
require "pathname"

module Factorix
  module Cache
    # File system based cache storage implementation
    class FileSystem
      LOCK_FILE_LIFETIME = 3600 # 1 hour in seconds
      public_constant :LOCK_FILE_LIFETIME

      # @param cache_dir [Pathname, String] path to the cache directory
      def initialize(cache_dir)
        @cache_dir = Pathname(cache_dir)
        @cache_dir.mkpath
      end

      # @param url_string [String] URL string to generate key for
      # @return [String] cache key
      def key_for(url_string)
        Digest::SHA1.hexdigest(url_string)
      end

      # Check if a cache entry exists for the given key
      #
      # @param key [String] cache key to check
      # @return [Boolean] true if the cache entry exists, false otherwise
      def exist?(key)
        cache_path_for(key).exist?
      end

      # Fetch a cached file and copy it to the output path
      #
      # @param key [String] cache key to fetch
      # @param output [Pathname, String] path to copy the cached file to
      # @return [Boolean] true if the cache entry was found and copied, false otherwise
      def fetch(key, output)
        path = cache_path_for(key)
        return false unless path.exist?

        FileUtils.cp(path, output)
        true
      end

      # Store a file in the cache
      #
      # @param key [String] cache key to store under
      # @param src [Pathname, String] path of the file to store
      # @return [void]
      def store(key, src)
        path = cache_path_for(key)
        path.dirname.mkpath
        FileUtils.cp(src, path)
      end

      # Executes the given block with a file lock
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
              lock_path.unlink rescue nil
            end
          end
        end
      end

      private def cache_path_for(key)
        prefix = key[0, 2]
        @cache_dir.join(prefix, key[2..])
      end

      private def lock_path_for(key)
        cache_path_for(key).sub_ext(".lock")
      end

      private def cleanup_stale_lock(lock_path)
        return if !lock_path.exist?
        return if (Time.now - lock_path.mtime) <= LOCK_FILE_LIFETIME

        lock_path.unlink rescue nil
      end
    end
  end
end
