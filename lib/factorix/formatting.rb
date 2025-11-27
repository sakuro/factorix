# frozen_string_literal: true

module Factorix
  # Formatting utilities for human-readable output
  #
  # This module provides methods for formatting sizes and durations
  # in a human-readable format for CLI output.
  #
  # @example
  #   include Factorix::Formatting
  #   format_size(1536)      # => "1.5 KiB"
  #   format_duration(3661)  # => "1h 1m"
  module Formatting
    # Format size value for display using binary prefixes (IEC)
    #
    # @param size [Integer, nil] size in bytes
    # @return [String] formatted size ("unlimited" if nil)
    def format_size(size)
      return "unlimited" if size.nil?
      return "0 B" if size == 0

      units = %w[B KiB MiB GiB TiB]
      unit_index = 0
      value = Float(size)

      while value >= 1024 && unit_index < units.size - 1
        value /= 1024
        unit_index += 1
      end

      unit_index == 0 ? "#{size} B" : "#{"%.1f" % value} #{units[unit_index]}"
    end

    # Format duration value for display
    #
    # @param seconds [Integer, Float, nil] duration in seconds
    # @return [String] formatted duration ("-" if nil)
    def format_duration(seconds)
      return "-" if seconds.nil?

      seconds = Integer(seconds)
      return "#{seconds}s" if seconds < 60

      minutes = seconds / 60
      return "#{minutes}m" if minutes < 60

      hours = minutes / 60
      remaining_minutes = minutes % 60
      return "#{hours}h #{remaining_minutes}m" if hours < 24

      days = hours / 24
      remaining_hours = hours % 24
      "#{days}d #{remaining_hours}h"
    end
  end
end
