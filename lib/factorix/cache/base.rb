# frozen_string_literal: true

module Factorix
  module Cache
    # Abstract base class for cache backends.
    #
    # All cache backends (FileSystem, S3, Redis) inherit from this class
    # and implement the abstract methods defined here.
    #
    # @abstract Subclasses must implement all abstract methods.
    class Base
      # @return [Integer, nil] time-to-live in seconds (nil for unlimited)
      attr_reader :ttl

      # Initialize a new cache backend.
      #
      # @param ttl [Integer, nil] time-to-live in seconds (nil for unlimited)
      def initialize(ttl: nil)
        @ttl = ttl
      end

      # Check if a cache entry exists and is not expired.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if the cache entry exists and is valid
      # @abstract
      def exist?(key) = raise NotImplementedError, "#{self.class}#exist? must be implemented"

      # Read a cached entry as a string.
      #
      # @param key [String] logical cache key
      # @return [String, nil] cached content or nil if not found/expired
      # @abstract
      def read(key) = raise NotImplementedError, "#{self.class}#read must be implemented"

      # Write cached content to a file.
      #
      # Unlike {#read} which returns content as a String, this method writes
      # directly to a file path, which is more memory-efficient for large files.
      #
      # @param key [String] logical cache key
      # @param output [Pathname] path to write the cached content
      # @return [Boolean] true if written successfully, false if not found/expired
      # @abstract
      def write_to(key, output) = raise NotImplementedError, "#{self.class}#write_to must be implemented"

      # Store data in the cache.
      #
      # @param key [String] logical cache key
      # @param src [Pathname] path to the source file
      # @return [Boolean] true if stored successfully
      # @abstract
      def store(key, src) = raise NotImplementedError, "#{self.class}#store must be implemented"

      # Delete a cache entry.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if deleted, false if not found
      # @abstract
      def delete(key) = raise NotImplementedError, "#{self.class}#delete must be implemented"

      # Clear all cache entries.
      #
      # @return [void]
      # @abstract
      def clear = raise NotImplementedError, "#{self.class}#clear must be implemented"

      # Execute a block with an exclusive lock on the cache entry.
      #
      # @param key [String] logical cache key
      # @yield block to execute with lock held
      # @abstract
      def with_lock(key) = raise NotImplementedError, "#{self.class}#with_lock must be implemented"

      # Get the age of a cache entry in seconds.
      #
      # @param key [String] logical cache key
      # @return [Float, nil] age in seconds, or nil if entry doesn't exist
      # @abstract
      def age(key) = raise NotImplementedError, "#{self.class}#age must be implemented"

      # Check if a cache entry has expired based on TTL.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if expired, false otherwise
      # @abstract
      def expired?(key) = raise NotImplementedError, "#{self.class}#expired? must be implemented"

      # Get the size of a cached entry in bytes.
      #
      # @param key [String] logical cache key
      # @return [Integer, nil] size in bytes, or nil if entry doesn't exist/expired
      # @abstract
      def size(key) = raise NotImplementedError, "#{self.class}#size must be implemented"

      # Enumerate cache entries.
      #
      # Yields [key, entry] pairs similar to Hash#each.
      #
      # @yield [key, entry] logical key and Entry object
      # @yieldparam key [String] logical cache key
      # @yieldparam entry [Entry] cache entry metadata
      # @return [Enumerator] if no block given
      # @abstract
      def each = raise NotImplementedError, "#{self.class}#each must be implemented"
    end
  end
end
