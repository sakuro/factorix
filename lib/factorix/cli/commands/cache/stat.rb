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

            cache_names = Factorix.config.cache.values.keys
            stats = cache_names.to_h {|name| [name, collect_stats(name)] }

            if json
              out.puts JSON.pretty_generate(stats)
            else
              output_text(stats)
            end
          end

          # Collect statistics for a cache
          #
          # @param name [Symbol] cache name
          # @return [Hash] cache statistics
          private def collect_stats(name)
            cache = Container.resolve(:"#{name}_cache")
            config = Factorix.config.cache.public_send(name)

            entries = scan_entries(cache)

            {
              ttl: config.ttl,
              entries: build_entry_stats(entries),
              size: build_size_stats(entries),
              age: build_age_stats(entries)
            }
          end

          # Collect cache entries using the cache interface
          #
          # @param cache [Cache::Base] cache instance
          # @return [Array<Cache::Entry>] array of cache entries
          private def scan_entries(cache)
            entries = []
            cache.each {|_key, entry| entries << entry }
            entries
          end

          # Build entry count statistics
          #
          # @param entries [Array<Cache::Entry>] entry array
          # @return [Hash] entry statistics
          private def build_entry_stats(entries)
            total = entries.size
            valid = entries.count {|e| !e.expired? }
            expired = total - valid

            {total:, valid:, expired:}
          end

          # Build size statistics
          #
          # @param entries [Array<Cache::Entry>] entry array
          # @return [Hash] size statistics
          private def build_size_stats(entries)
            return {total: 0, avg: 0, min: 0, max: 0} if entries.empty?

            sizes = entries.map(&:size)
            {total: sizes.sum, avg: sizes.sum / sizes.size, min: sizes.min, max: sizes.max}
          end

          # Build age statistics
          #
          # @param entries [Array<Cache::Entry>] entry array
          # @return [Hash] age statistics
          private def build_age_stats(entries)
            return {oldest: nil, newest: nil, avg: nil} if entries.empty?

            ages = entries.map(&:age)
            {oldest: ages.max, newest: ages.min, avg: ages.sum / ages.size}
          end

          # Output statistics in text format (ccache-style)
          #
          # @param stats [Hash] statistics for all caches
          # @return [void]
          private def output_text(stats)
            stats.each_with_index do |(name, data), index|
              out.puts if index > 0
              out.puts "#{name}:"
              output_cache_stats(data)
            end
          end

          # Output statistics for a single cache
          #
          # @param data [Hash] cache statistics
          # @return [void]
          private def output_cache_stats(data)
            out.puts "  TTL:            #{format_ttl(data[:ttl])}"

            entries = data[:entries]
            valid_pct = entries[:total] > 0 ? (Float(entries[:valid]) / entries[:total] * 100) : 0.0
            out.puts "  Entries:        #{entries[:valid]} / #{entries[:total]} (#{"%.1f" % valid_pct}% valid)"

            size = data[:size]
            out.puts "  Size:           #{format_size(size[:total])} (avg #{format_size(size[:avg])})"

            age = data[:age]
            if age[:oldest]
              out.puts "  Age:            #{format_duration(age[:newest])} - #{format_duration(age[:oldest])} (avg #{format_duration(age[:avg])})"
            else
              out.puts "  Age:            -"
            end
          end

          # Format TTL value for display
          #
          # @param ttl [Integer, nil] TTL in seconds
          # @return [String] formatted TTL
          private def format_ttl(ttl)
            ttl.nil? ? "unlimited" : format_duration(ttl)
          end
        end
      end
    end
  end
end
