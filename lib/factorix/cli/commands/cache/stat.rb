# frozen_string_literal: true

require "json"

module Factorix
  class CLI
    module Commands
      module Cache
        # Display cache statistics
        #
        # This command outputs statistics for all cache stores
        # in a human-readable or JSON format.
        #
        # @example
        #   $ factorix cache stat
        #   download:
        #     Directory:      ~/.cache/factorix/download
        #     TTL:            unlimited
        #     Entries:        42 / 42 (100.0% valid)
        #     ...
        class Stat < Base
          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          include Import[:logger]
          include Formatting

          desc "Display cache statistics"

          example [
            "        # Display statistics in text format",
            "--json  # Display statistics in JSON format"
          ]

          option :json, type: :flag, default: false, desc: "Output in JSON format"

          # Execute the cache stat command
          #
          # @param json [Boolean] output in JSON format
          # @return [void]
          def call(json:, **)
            logger.debug("Collecting cache statistics")

            @now = Time.now
            cache_names = Container.config.cache.values.keys
            stats = cache_names.to_h {|name| [name, collect_stats(name)] }

            if json
              puts JSON.pretty_generate(stats)
            else
              output_text(stats)
            end
          end

          private def collect_stats(name)
            config = Container.config.cache.public_send(name)
            cache_dir = config.dir

            entries = scan_entries(cache_dir, config.ttl)

            {
              directory: cache_dir.to_s,
              ttl: config.ttl,
              max_file_size: config.max_file_size,
              compression_threshold: config.compression_threshold,
              entries: build_entry_stats(entries),
              size: build_size_stats(entries),
              age: build_age_stats(entries),
              stale_locks: count_stale_locks(cache_dir)
            }
          end

          # Scan cache directory and collect entry information
          #
          # @param cache_dir [Pathname] cache directory path
          # @param ttl [Integer, nil] time-to-live in seconds
          # @return [Array<Hash>] array of entry info hashes
          private def scan_entries(cache_dir, ttl)
            return [] unless cache_dir.exist?

            entries = []
            cache_dir.glob("**/*").each do |path|
              next unless path.file?
              next if path.extname == ".lock"

              age_seconds = @now - path.mtime
              expired = ttl ? age_seconds > ttl : false

              entries << {size: path.size, age: age_seconds, expired:}
            end
            entries
          end

          # Build entry count statistics
          #
          # @param entries [Array<Hash>] entry info array
          # @return [Hash] entry statistics
          private def build_entry_stats(entries)
            total = entries.size
            valid = entries.count {|e| !e[:expired] }
            expired = total - valid

            {total:, valid:, expired:}
          end

          # Build size statistics
          #
          # @param entries [Array<Hash>] entry info array
          # @return [Hash] size statistics
          private def build_size_stats(entries)
            return {total: 0, avg: 0, min: 0, max: 0} if entries.empty?

            sizes = entries.map {|e| e[:size] }
            {total: sizes.sum, avg: sizes.sum / sizes.size, min: sizes.min, max: sizes.max}
          end

          # Build age statistics
          #
          # @param entries [Array<Hash>] entry info array
          # @return [Hash] age statistics
          private def build_age_stats(entries)
            return {oldest: nil, newest: nil, avg: nil} if entries.empty?

            ages = entries.map {|e| e[:age] }
            {oldest: ages.max, newest: ages.min, avg: ages.sum / ages.size}
          end

          # Count stale lock files
          #
          # @param cache_dir [Pathname] cache directory path
          # @return [Integer] number of stale lock files
          private def count_stale_locks(cache_dir)
            return 0 unless cache_dir.exist?

            lock_lifetime = Factorix::Cache::FileSystem::LOCK_FILE_LIFETIME
            cache_dir.glob("**/*.lock").count {|path| @now - path.mtime > lock_lifetime }
          end

          # Output statistics in text format (ccache-style)
          #
          # @param stats [Hash] statistics for all caches
          # @return [void]
          private def output_text(stats)
            stats.each_with_index do |(name, data), index|
              puts if index > 0
              puts "#{name}:"
              output_cache_stats(data)
            end
          end

          # Output statistics for a single cache
          #
          # @param data [Hash] cache statistics
          # @return [void]
          private def output_cache_stats(data)
            puts "  Directory:      #{data[:directory]}"
            puts "  TTL:            #{format_ttl(data[:ttl])}"
            puts "  Max file size:  #{format_size(data[:max_file_size])}"
            puts "  Compression:    #{format_compression(data[:compression_threshold])}"

            entries = data[:entries]
            valid_pct = entries[:total] > 0 ? (Float(entries[:valid]) / entries[:total] * 100) : 0.0
            puts "  Entries:        #{entries[:valid]} / #{entries[:total]} (#{"%.1f" % valid_pct}% valid)"

            size = data[:size]
            puts "  Size:           #{format_size(size[:total])} (avg #{format_size(size[:avg])})"

            age = data[:age]
            if age[:oldest]
              puts "  Age:            #{format_duration(age[:newest])} - #{format_duration(age[:oldest])} (avg #{format_duration(age[:avg])})"
            else
              puts "  Age:            -"
            end

            puts "  Stale locks:    #{data[:stale_locks]}"
          end

          # Format TTL value for display
          #
          # @param ttl [Integer, nil] TTL in seconds
          # @return [String] formatted TTL
          private def format_ttl(ttl)
            ttl.nil? ? "unlimited" : format_duration(ttl)
          end

          # Format compression threshold for display
          #
          # @param threshold [Integer, nil] compression threshold in bytes
          # @return [String] formatted compression setting
          private def format_compression(threshold)
            case threshold
            when nil then "disabled"
            when 0 then "enabled (always)"
            else "enabled (>= #{format_size(threshold)})"
            end
          end
        end
      end
    end
  end
end
