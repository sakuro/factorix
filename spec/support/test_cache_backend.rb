# frozen_string_literal: true

module Factorix
  module Cache
    # Test backend for cache CLI command testing.
    #
    # This backend stores entries in memory and provides test helper methods
    # for manipulating entry age and stale locks count.
    #
    # @example Basic usage
    #   cache = Factorix::Cache::TestBackend.new(ttl: 3600)
    #   cache.store("key", Pathname("/path/to/file"))
    #   cache.set_entry_age("key", 7200) # Make entry 2 hours old (expired)
    #
    class TestBackend < Base
      # Initialize a new test backend.
      #
      # @param ttl [Integer, nil] time-to-live in seconds (nil for unlimited)
      def initialize(ttl: nil)
        super
        @entries = {}
      end

      # Check if a cache entry exists and is not expired.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if the cache entry exists and is valid
      def exist?(key)
        return false unless @entries.key?(key)

        !expired?(key)
      end

      # Read a cached entry as a string.
      #
      # @param key [String] logical cache key
      # @param encoding [Encoding] encoding to use (default: ASCII-8BIT for binary)
      # @return [String, nil] cached content or nil if not found/expired
      def read(key, encoding: Encoding::ASCII_8BIT)
        return nil unless exist?(key)

        @entries[key][:data].dup.force_encoding(encoding)
      end

      # Write cached content to a file.
      #
      # @param key [String] logical cache key
      # @param output [Pathname] path to write the cached content
      # @return [Boolean] true if written successfully, false if not found/expired
      def write_to(key, output)
        return false unless exist?(key)

        output.binwrite(@entries[key][:data])
        true
      end

      # Store data in the cache.
      #
      # @param key [String] logical cache key
      # @param src [Pathname] path to the source file
      # @return [Boolean] true if stored successfully
      def store(key, src)
        data = src.binread
        @entries[key] = {data:, stored_at: Time.now, size: data.bytesize}
        true
      end

      # Delete a cache entry.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if deleted, false if not found
      def delete(key)
        !!@entries.delete(key)
      end

      # Clear all cache entries.
      #
      # @return [void]
      def clear
        @entries.clear
      end

      # Execute a block with an exclusive lock on the cache entry.
      #
      # @param key [String] logical cache key
      # @yield block to execute with lock held
      def with_lock(_key)
        yield
      end

      # Get the age of a cache entry in seconds.
      #
      # @param key [String] logical cache key
      # @return [Float, nil] age in seconds, or nil if entry doesn't exist
      def age(key)
        return nil unless @entries.key?(key)

        Time.now - @entries[key][:stored_at]
      end

      # Check if a cache entry has expired based on TTL.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if expired, false otherwise
      def expired?(key)
        return false unless @entries.key?(key)
        return false if @ttl.nil?

        age(key) > @ttl
      end

      # Get the size of a cached entry in bytes.
      #
      # @param key [String] logical cache key
      # @return [Integer, nil] size in bytes, or nil if entry doesn't exist/expired
      def size(key)
        return nil unless exist?(key)

        @entries[key][:size]
      end

      # Enumerate cache entries.
      #
      # @yield [key, entry] logical key and Entry object
      # @yieldparam key [String] logical cache key
      # @yieldparam entry [Entry] cache entry metadata
      # @return [Enumerator] if no block given
      def each
        return enum_for(__method__) unless block_given?

        @entries.each do |key, data|
          age = Time.now - data[:stored_at]
          entry = Entry.new(
            size: data[:size],
            age:,
            expired: @ttl ? age > @ttl : false
          )
          yield key, entry
        end
      end

      # Test helper: Set the age of a cache entry.
      #
      # @param key [String] logical cache key
      # @param age_seconds [Numeric] age in seconds
      # @return [void]
      def set_entry_age(key, age_seconds)
        return unless @entries.key?(key)

        @entries[key][:stored_at] = Time.now - age_seconds
      end

      # Test helper: Add an entry directly with specified properties.
      #
      # @param key [String] logical cache key
      # @param content [String] entry content
      # @param age [Numeric] entry age in seconds (default: 0)
      # @return [void]
      def add_entry(key, content, age: 0)
        @entries[key] = {
          data: content.b,
          stored_at: Time.now - age,
          size: content.bytesize
        }
      end

      # Return backend-specific information.
      #
      # @return [Hash] test backend configuration
      def backend_info
        {
          type: "memory",
          entries_count: @entries.size
        }
      end
    end
  end
end
