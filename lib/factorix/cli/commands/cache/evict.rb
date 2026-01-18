# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module Cache
        # Evict cache entries
        #
        # This command removes cache entries based on the specified criteria.
        # At least one of --all, --expired, or --older-than must be specified.
        #
        # @example
        #   $ factorix cache evict --expired
        #   $ factorix cache evict api --all
        #   $ factorix cache evict download --older-than 7d
        class Evict < Base
          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          include Import[:logger]
          include Formatting

          # Valid cache names for the caches argument
          VALID_CACHES = %w[download api info_json].freeze
          private_constant :VALID_CACHES

          desc "Evict cache entries"

          example [
            "--expired              # Remove expired entries from all caches",
            "api --all              # Remove all entries from api cache",
            "download --older-than 7d  # Remove entries older than 7 days"
          ]

          argument :caches, type: :array, required: false, values: VALID_CACHES, desc: "Cache names"

          option :all, type: :flag, default: false, desc: "Remove all entries"
          option :expired, type: :flag, default: false, desc: "Remove expired entries only"
          option :older_than, default: nil, desc: "Remove entries older than AGE (e.g., 30s, 5m, 2h, 7d)"

          # Execute the cache evict command
          #
          # @param caches [Array<String>, nil] cache names to evict
          # @param all [Boolean] remove all entries
          # @param expired [Boolean] remove expired entries only
          # @param older_than [String, nil] remove entries older than this age
          # @return [void]
          def call(caches: nil, all: false, expired: false, older_than: nil, **)
            validate_options!(all, expired, older_than)

            @now = Time.now
            @older_than_seconds = parse_age(older_than) if older_than

            cache_names = resolve_cache_names(caches)
            results = cache_names.to_h {|name| [name, evict_cache(name, all:, expired:)] }

            output_results(results)
          end

          # Validate that exactly one eviction option is specified
          #
          # @param all [Boolean] --all option
          # @param expired [Boolean] --expired option
          # @param older_than [String, nil] --older-than option
          # @return [void]
          # @raise [InvalidArgumentError] if options are invalid
          private def validate_options!(all, expired, older_than)
            options_count = [all, expired, older_than].count {|opt| opt }

            raise InvalidArgumentError, "One of --all, --expired, or --older-than must be specified" if options_count == 0
            raise InvalidArgumentError, "Only one of --all, --expired, or --older-than can be specified" if options_count > 1
          end

          # Parse age string into seconds
          #
          # @param age [String] age string (e.g., "30s", "5m", "2h", "7d")
          # @return [Integer] age in seconds
          # @raise [InvalidArgumentError] if age format is invalid
          DURATION_MULTIPLIERS = {"s" => 1, "m" => 60, "h" => 3600, "d" => 86400}.freeze
          private_constant :DURATION_MULTIPLIERS

          private def parse_age(age)
            match = age.match(/\A(\d+)([smhd])\z/)
            raise InvalidArgumentError, "Invalid age format: #{age}. Use format like 30s, 5m, 2h, 7d" unless match

            value = Integer(match[1])
            unit = match[2]

            value * DURATION_MULTIPLIERS.fetch(unit)
          end

          # Resolve cache names from argument or return all
          #
          # @param caches [Array<String>, nil] cache names from argument
          # @return [Array<Symbol>] resolved cache names
          # @raise [InvalidArgumentError] if unknown cache name specified
          private def resolve_cache_names(caches)
            all_caches = Factorix.config.cache.values.keys

            return all_caches if caches.nil? || caches.empty?

            caches.map do |name|
              sym = name.to_sym
              raise InvalidArgumentError, "Unknown cache: #{name}. Valid caches: #{all_caches.join(", ")}" unless all_caches.include?(sym)

              sym
            end
          end

          # Evict entries from a single cache
          #
          # @param name [Symbol] cache name
          # @param all [Boolean] remove all entries
          # @param expired [Boolean] remove expired entries only
          # @return [Hash] eviction result with :count and :size
          private def evict_cache(name, all:, expired:)
            config = Factorix.config.cache.public_send(name)
            cache_dir = config.dir
            ttl = config.ttl

            return {count: 0, size: 0} unless cache_dir.exist?

            count = 0
            size = 0

            cache_dir.glob("**/*").each do |path|
              next unless path.file?
              next if path.extname == ".lock"

              next unless should_evict?(path, ttl, all:, expired:)

              size += path.size
              path.delete
              count += 1
              logger.debug("Evicted cache entry", path: path.to_s)
            end

            logger.info("Evicted cache entries", cache: name, count:, size:)
            {count:, size:}
          end

          # Determine if a cache entry should be evicted
          #
          # @param path [Pathname] path to cache entry
          # @param ttl [Integer, nil] cache TTL
          # @param all [Boolean] remove all entries
          # @param expired [Boolean] remove expired entries only
          # @return [Boolean] true if entry should be evicted
          private def should_evict?(path, ttl, all:, expired:)
            return true if all

            age_seconds = @now - path.mtime

            if expired
              return false if ttl.nil? # No TTL means never expires

              age_seconds > ttl
            else
              # --older-than
              age_seconds > @older_than_seconds
            end
          end

          # Output eviction results
          #
          # @param results [Hash] results for each cache
          # @return [void]
          private def output_results(results)
            # Calculate max width for alignment
            max_name_width = results.keys.map {|k| k.to_s.length }.max

            results.each do |name, data|
              say "%-#{max_name_width}s: %3d entries removed (%s)" % [name, data[:count], format_size(data[:size])], prefix: :info
            end
          end
        end
      end
    end
  end
end
