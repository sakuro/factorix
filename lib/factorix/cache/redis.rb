# frozen_string_literal: true

begin
  require "redis"
rescue LoadError
  raise Factorix::Error, "redis gem is required for Redis cache backend. Add it to your Gemfile."
end

require "securerandom"

module Factorix
  module Cache
    # Redis-based cache storage implementation.
    #
    # Stores cache entries in Redis with automatic namespace prefixing.
    # Metadata (size, created_at) stored in separate hash keys.
    # Supports distributed locking with Lua script for atomic release.
    #
    # @example Configuration
    #   Factorix.configure do |config|
    #     config.cache.api.backend = :redis
    #     config.cache.api.redis.url = "redis://localhost:6379/0"
    #     config.cache.api.redis.lock_timeout = 30
    #   end
    class Redis < Base
      # @!parse
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      include Import[:logger]

      # Default timeout for distributed lock acquisition in seconds.
      DEFAULT_LOCK_TIMEOUT = 30
      public_constant :DEFAULT_LOCK_TIMEOUT

      # TTL for distributed locks in seconds.
      LOCK_TTL = 30
      private_constant :LOCK_TTL

      # Lua script for atomic lock release (only release if we own it).
      RELEASE_LOCK_SCRIPT = <<~LUA
        if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
        else
          return 0
        end
      LUA
      private_constant :RELEASE_LOCK_SCRIPT

      # Initialize a new Redis cache storage.
      #
      # @param url [String, nil] Redis URL (defaults to REDIS_URL env)
      # @param cache_type [String, Symbol] Cache type for namespace (e.g., :api, :download)
      # @param lock_timeout [Integer] Timeout for lock acquisition in seconds
      # @param ttl [Integer, nil] time-to-live in seconds (nil for unlimited)
      def initialize(cache_type:, url: nil, lock_timeout: DEFAULT_LOCK_TIMEOUT, **)
        super(**)
        @url = url || ENV.fetch("REDIS_URL", nil)
        @redis = ::Redis.new(url: @url)
        @namespace = "factorix-cache:#{cache_type}"
        @lock_timeout = lock_timeout
        logger.info("Initializing Redis cache", namespace: @namespace, ttl: @ttl, lock_timeout: @lock_timeout)
      end

      # Check if a cache entry exists.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if the cache entry exists
      def exist?(key) = @redis.exists?(data_key(key))

      # Read a cached entry.
      #
      # @param key [String] logical cache key
      # @return [String, nil] cached content or nil if not found
      def read(key)
        @redis.get(data_key(key))
      end

      # Write cached content to a file.
      #
      # @param key [String] logical cache key
      # @param output [Pathname] path to write the cached content
      # @return [Boolean] true if written successfully, false if not found
      def write_to(key, output)
        data = @redis.get(data_key(key))
        return false if data.nil?

        output.binwrite(data)
        logger.debug("Cache hit", key:)
        true
      end

      # Store data in the cache.
      #
      # @param key [String] logical cache key
      # @param src [Pathname] path to the source file
      # @return [Boolean] true if stored successfully
      def store(key, src)
        data = src.binread
        data_k = data_key(key)
        meta_k = meta_key(key)

        @redis.multi do |tx|
          tx.set(data_k, data)
          tx.hset(meta_k, "size", data.bytesize, "created_at", Time.now.to_i)

          if @ttl
            tx.expire(data_k, @ttl)
            tx.expire(meta_k, @ttl)
          end
        end

        logger.debug("Stored in cache", key:, size_bytes: data.bytesize)
        true
      end

      # Delete a cache entry.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if deleted, false if not found
      def delete(key)
        deleted = @redis.del(data_key(key), meta_key(key))
        logger.debug("Deleted from cache", key:) if deleted.positive?
        deleted.positive?
      end

      # Clear all cache entries in this namespace.
      #
      # @return [void]
      def clear
        logger.info("Clearing Redis cache namespace", namespace: @namespace)
        count = 0
        cursor = "0"
        pattern = "#{@namespace}:*"

        loop do
          cursor, keys = @redis.scan(cursor, match: pattern, count: 100)
          unless keys.empty?
            @redis.del(*keys)
            count += keys.size
          end
          break if cursor == "0"
        end

        logger.info("Cache cleared", keys_removed: count)
      end

      # Get the age of a cache entry in seconds.
      #
      # @param key [String] logical cache key
      # @return [Integer, nil] age in seconds, or nil if entry doesn't exist
      def age(key)
        value = @redis.hget(meta_key(key), "created_at")
        return nil if value.nil?

        created_at = Integer(value, 10)
        return nil if created_at.zero?

        Time.now.to_i - created_at
      end

      # Check if a cache entry has expired.
      # With Redis native EXPIRE, non-existent keys are considered expired.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if expired (or doesn't exist), false otherwise
      def expired?(key) = !exist?(key)

      # Get the size of a cached entry in bytes.
      #
      # @param key [String] logical cache key
      # @return [Integer, nil] size in bytes, or nil if entry doesn't exist
      def size(key)
        return nil unless exist?(key)

        value = @redis.hget(meta_key(key), "size")
        value.nil? ? nil : Integer(value, 10)
      end

      # Execute a block with a distributed lock.
      # Uses Redis SET NX EX for lock acquisition and Lua script for atomic release.
      #
      # @param key [String] logical cache key
      # @yield block to execute with lock held
      # @raise [LockTimeoutError] if lock cannot be acquired within timeout
      def with_lock(key)
        lkey = lock_key(key)
        lock_value = SecureRandom.uuid
        deadline = Time.now + @lock_timeout

        until @redis.set(lkey, lock_value, nx: true, ex: LOCK_TTL)
          raise LockTimeoutError, "Failed to acquire lock for key: #{key}" if Time.now > deadline

          sleep 0.1
        end

        logger.debug("Acquired lock", key:)
        begin
          yield
        ensure
          @redis.eval(RELEASE_LOCK_SCRIPT, keys: [lkey], argv: [lock_value])
          logger.debug("Released lock", key:)
        end
      end

      # Enumerate cache entries.
      #
      # @yield [key, entry] logical key and Entry object
      # @yieldparam key [String] logical cache key
      # @yieldparam entry [Entry] cache entry metadata
      # @return [Enumerator] if no block given
      def each
        return enum_for(__method__) unless block_given?

        cursor = "0"
        pattern = "#{@namespace}:*"

        loop do
          cursor, keys = @redis.scan(cursor, match: pattern, count: 100)

          keys.each do |data_k|
            next if data_k.include?(":meta:") || data_k.include?(":lock:")

            logical_key = logical_key_from_data_key(data_k)
            meta = @redis.hgetall(meta_key(logical_key))

            entry = Entry.new(
              size: meta["size"] ? Integer(meta["size"], 10) : 0,
              age: meta["created_at"] ? Time.now.to_i - Integer(meta["created_at"], 10) : 0,
              expired: false # Redis handles expiry natively
            )

            yield logical_key, entry
          end

          break if cursor == "0"
        end
      end

      # Return backend-specific information.
      #
      # @return [Hash] backend configuration
      def backend_info
        {
          type: "redis",
          url: mask_url(@url),
          namespace: @namespace,
          lock_timeout: @lock_timeout
        }
      end

      # Generate data key for the given logical key.
      #
      # @param logical_key [String] logical key
      # @return [String] namespaced data key
      private def data_key(logical_key) = "#{@namespace}:#{logical_key}"

      # Generate metadata key for the given logical key.
      #
      # @param logical_key [String] logical key
      # @return [String] namespaced metadata key
      private def meta_key(logical_key) = "#{@namespace}:meta:#{logical_key}"

      # Generate lock key for the given logical key.
      #
      # @param logical_key [String] logical key
      # @return [String] namespaced lock key
      private def lock_key(logical_key) = "#{@namespace}:lock:#{logical_key}"

      # Extract logical key from data key.
      #
      # @param data_k [String] namespaced data key
      # @return [String] logical key
      private def logical_key_from_data_key(data_k) = data_k.delete_prefix("#{@namespace}:")

      DEFAULT_URL = "redis://localhost:6379/0"
      private_constant :DEFAULT_URL

      # Mask credentials in Redis URL for safe display.
      #
      # @param url [String, nil] Redis URL
      # @return [String] URL with credentials masked (defaults to redis://localhost:6379/0)
      private def mask_url(url)
        URI.parse(url || DEFAULT_URL).tap {|uri| uri.userinfo = "***:***" if uri.userinfo }.to_s
      end
    end
  end
end
