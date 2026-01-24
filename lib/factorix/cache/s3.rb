# frozen_string_literal: true

begin
  require "aws-sdk-s3"
rescue LoadError
  raise Factorix::Error, "aws-sdk-s3 gem is required for S3 cache backend. Add it to your Gemfile."
end

require "securerandom"

module Factorix
  module Cache
    # S3-based cache storage implementation.
    #
    # Stores cache entries in AWS S3 with automatic prefix generation.
    # TTL is managed via custom metadata on objects.
    # Supports distributed locking using conditional PUT operations.
    #
    # @example Configuration
    #   Factorix.configure do |config|
    #     config.cache.download.backend = :s3
    #     config.cache.download.s3.bucket = "factorix-develop"
    #     config.cache.download.s3.region = "ap-northeast-1"
    #     config.cache.download.s3.lock_timeout = 30
    #   end
    class S3 < Base
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

      # Metadata key for storing expiration timestamp.
      EXPIRES_AT_KEY = "expires-at"
      private_constant :EXPIRES_AT_KEY

      # Metadata key for storing creation timestamp.
      CREATED_AT_KEY = "created-at"
      private_constant :CREATED_AT_KEY

      # Initialize a new S3 cache storage.
      #
      # @param bucket [String] S3 bucket name (required)
      # @param region [String, nil] AWS region (defaults to AWS_REGION env or SDK default)
      # @param cache_type [String, Symbol] Cache type for prefix (e.g., :api, :download)
      # @param lock_timeout [Integer] Timeout for lock acquisition in seconds
      # @param ttl [Integer, nil] time-to-live in seconds (nil for unlimited)
      def initialize(bucket:, cache_type:, region: nil, lock_timeout: DEFAULT_LOCK_TIMEOUT, **)
        super(**)
        @client = Aws::S3::Client.new(region:)
        @bucket = bucket
        @prefix = "cache/#{cache_type}/"
        @lock_timeout = lock_timeout
        logger.info("Initializing S3 cache", bucket: @bucket, prefix: @prefix, ttl: @ttl, lock_timeout: @lock_timeout)
      end

      # Check if a cache entry exists and is not expired.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if the cache entry exists and is valid
      def exist?(key)
        head_object(key)
        !expired?(key)
      rescue Aws::S3::Errors::NotFound
        false
      end

      # Read a cached entry.
      #
      # @param key [String] logical cache key
      # @return [String, nil] cached content or nil if not found/expired
      def read(key)
        return nil if expired?(key)

        resp = @client.get_object(bucket: @bucket, key: storage_key(key))
        resp.body.read
      rescue Aws::S3::Errors::NotFound
        nil
      end

      # Write cached content to a file.
      #
      # @param key [String] logical cache key
      # @param output [Pathname] path to write the cached content
      # @return [Boolean] true if written successfully, false if not found/expired
      def write_to(key, output)
        return false if expired?(key)

        resp = @client.get_object(bucket: @bucket, key: storage_key(key))
        output.binwrite(resp.body.read)
        logger.debug("Cache hit", key:)
        true
      rescue Aws::S3::Errors::NotFound
        false
      end

      # Store data in the cache.
      #
      # @param key [String] logical cache key
      # @param src [Pathname] path to the source file
      # @return [Boolean] true if stored successfully
      def store(key, src)
        metadata = {CREATED_AT_KEY => Time.now.to_i.to_s}
        metadata[EXPIRES_AT_KEY] = (Time.now.to_i + @ttl).to_s if @ttl

        @client.put_object(
          bucket: @bucket,
          key: storage_key(key),
          body: src.binread,
          metadata:
        )

        logger.debug("Stored in cache", key:, size_bytes: src.size)
        true
      end

      # Delete a cache entry.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if deleted, false if not found
      def delete(key)
        return false unless exist_without_expiry_check?(key)

        @client.delete_object(bucket: @bucket, key: storage_key(key))
        logger.debug("Deleted from cache", key:)
        true
      end

      # Clear all cache entries in this prefix.
      #
      # @return [void]
      def clear
        logger.info("Clearing S3 cache prefix", bucket: @bucket, prefix: @prefix)
        count = 0

        list_all_objects do |objects|
          keys_to_delete = objects.filter_map {|obj| {key: obj.key} unless obj.key.end_with?(".lock") }
          next if keys_to_delete.empty?

          @client.delete_objects(bucket: @bucket, delete: {objects: keys_to_delete})
          count += keys_to_delete.size
        end

        logger.info("Cache cleared", objects_removed: count)
      end

      # Get the age of a cache entry in seconds.
      #
      # @param key [String] logical cache key
      # @return [Integer, nil] age in seconds, or nil if entry doesn't exist
      def age(key)
        resp = head_object(key)
        value = resp.metadata[CREATED_AT_KEY]
        return nil if value.nil?

        Time.now.to_i - Integer(value, 10)
      rescue Aws::S3::Errors::NotFound
        nil
      end

      # Check if a cache entry has expired based on TTL.
      #
      # @param key [String] logical cache key
      # @return [Boolean] true if expired, false otherwise
      def expired?(key)
        return false if @ttl.nil?

        resp = head_object(key)
        value = resp.metadata[EXPIRES_AT_KEY]
        return false if value.nil?

        Time.now.to_i > Integer(value, 10)
      rescue Aws::S3::Errors::NotFound
        true
      end

      # Get the size of a cached entry in bytes.
      #
      # @param key [String] logical cache key
      # @return [Integer, nil] size in bytes, or nil if entry doesn't exist/expired
      def size(key)
        return nil if expired?(key)

        resp = head_object(key)
        resp.content_length
      rescue Aws::S3::Errors::NotFound
        nil
      end

      # Execute a block with a distributed lock.
      # Uses conditional PUT for lock acquisition.
      #
      # @param key [String] logical cache key
      # @yield block to execute with lock held
      # @raise [LockTimeoutError] if lock cannot be acquired within timeout
      def with_lock(key)
        lkey = lock_key(key)
        lock_value = SecureRandom.uuid
        deadline = Time.now + @lock_timeout

        loop do
          if try_acquire_lock(lkey, lock_value)
            logger.debug("Acquired lock", key:)
            break
          end

          cleanup_stale_lock(lkey)
          raise LockTimeoutError, "Failed to acquire lock for key: #{key}" if Time.now > deadline

          sleep 0.1
        end

        begin
          yield
        ensure
          @client.delete_object(bucket: @bucket, key: lkey)
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

        list_all_objects do |objects|
          objects.each do |obj|
            next if obj.key.end_with?(".lock")

            logical_key = logical_key_from_storage_key(obj.key)
            entry = build_entry(obj)

            yield logical_key, entry
          end
        end
      end

      # Return backend-specific information.
      #
      # @return [Hash] backend configuration
      def backend_info
        {
          type: "s3",
          bucket: @bucket,
          prefix: @prefix,
          lock_timeout: @lock_timeout
        }
      end

      # Generate storage key for the given logical key.
      #
      # @param logical_key [String] logical key
      # @return [String] prefixed storage key
      private def storage_key(logical_key) = "#{@prefix}#{logical_key}"

      # Generate lock key for the given logical key.
      #
      # @param logical_key [String] logical key
      # @return [String] lock key
      private def lock_key(logical_key) = "#{@prefix}#{logical_key}.lock"

      # Extract logical key from storage key.
      #
      # @param s_key [String] prefixed storage key
      # @return [String] logical key
      private def logical_key_from_storage_key(s_key) = s_key.delete_prefix(@prefix)

      # Get object metadata.
      #
      # @param key [String] logical key
      # @return [Aws::S3::Types::HeadObjectOutput] object metadata
      private def head_object(key)
        @client.head_object(bucket: @bucket, key: storage_key(key))
      end

      # Check if object exists without expiry check.
      #
      # @param key [String] logical key
      # @return [Boolean] true if exists
      private def exist_without_expiry_check?(key)
        head_object(key)
        true
      rescue Aws::S3::Errors::NotFound
        false
      end

      # Try to acquire a distributed lock.
      #
      # @param lkey [String] lock key
      # @param lock_value [String] unique lock value
      # @return [Boolean] true if lock acquired
      private def try_acquire_lock(lkey, lock_value)
        lock_body = "#{lock_value}:#{Time.now.to_i + LOCK_TTL}"
        @client.put_object(
          bucket: @bucket,
          key: lkey,
          body: lock_body,
          if_none_match: "*"
        )
        true
      rescue Aws::S3::Errors::PreconditionFailed
        false
      end

      # Clean up stale lock if expired.
      #
      # @param lkey [String] lock key
      private def cleanup_stale_lock(lkey)
        resp = @client.get_object(bucket: @bucket, key: lkey)
        lock_data = resp.body.read
        _lock_value, expires_at = lock_data.split(":")

        if expires_at && Time.now.to_i > Integer(expires_at, 10)
          @client.delete_object(bucket: @bucket, key: lkey)
          logger.debug("Cleaned up stale lock", key: lkey)
        end
      rescue Aws::S3::Errors::NotFound
        # Lock doesn't exist, nothing to clean up
      end

      # List all objects in the prefix with pagination.
      #
      # @yield [Array<Aws::S3::Types::Object>] batch of objects
      private def list_all_objects
        continuation_token = nil

        loop do
          resp = @client.list_objects_v2(
            bucket: @bucket,
            prefix: @prefix,
            continuation_token:
          )

          yield resp.contents if resp.contents.any?

          break unless resp.is_truncated

          continuation_token = resp.next_continuation_token
        end
      end

      # Build an Entry from an S3 object.
      #
      # @param obj [Aws::S3::Types::Object] S3 object
      # @return [Entry] cache entry
      private def build_entry(obj)
        age = Time.now - obj.last_modified
        expired = check_expired_from_metadata(obj.key)

        Entry.new(
          size: obj.size,
          age:,
          expired:
        )
      end

      # Check if object is expired by fetching metadata.
      #
      # @param storage_key [String] storage key
      # @return [Boolean] true if expired
      private def check_expired_from_metadata(storage_key)
        return false if @ttl.nil?

        resp = @client.head_object(bucket: @bucket, key: storage_key)
        value = resp.metadata[EXPIRES_AT_KEY]
        return false if value.nil?

        Time.now.to_i > Integer(value, 10)
      rescue Aws::S3::Errors::NotFound
        true
      end
    end
  end
end
