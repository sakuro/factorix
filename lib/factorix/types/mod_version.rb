# frozen_string_literal: true

module Factorix
  module Types
    MODVersion = Data.define(:major, :minor, :patch)

    # Represent a 3-component MOD version number (major.minor.patch)
    #
    # This class represents Factorio's MOD version format, which uses
    # 24 bits (3 x 8-bit unsigned integers) to store version information.
    #
    # @see https://wiki.factorio.com/Version_string_format
    class MODVersion
      include Comparable

      # @!attribute [r] major
      #   @return [Integer] major version number (0-255)
      # @!attribute [r] minor
      #   @return [Integer] minor version number (0-255)
      # @!attribute [r] patch
      #   @return [Integer] patch version number (0-255)

      UINT8_MAX = (2**8) - 1
      private_constant :UINT8_MAX

      class << self
        private def validate_component(value, name)
          raise ArgumentError, "#{name} must be an Integer, got #{value.class}" unless value.is_a?(Integer)
          return if value.between?(0, UINT8_MAX)

          raise RangeError, "#{name} must be between 0 and #{UINT8_MAX}, got #{value}"
        end
      end

      # Create MODVersion from version string "X.Y.Z" or "X.Y"
      #
      # Accepts both 3-part (X.Y.Z) and 2-part (X.Y) version strings.
      # For 2-part versions, patch defaults to 0.
      #
      # @param str [String] version string in "X.Y.Z" or "X.Y" format
      # @return [MODVersion]
      # @raise [ArgumentError] if string format is invalid
      def self.from_string(str)
        # Try 3-part version first (X.Y.Z)
        if /\A(\d+)\.(\d+)\.(\d+)\z/ =~ str
          major = Integer($1, 10)
          minor = Integer($2, 10)
          patch = Integer($3, 10)
        # Try 2-part version (X.Y), patch defaults to 0
        elsif /\A(\d+)\.(\d+)\z/ =~ str
          major = Integer($1, 10)
          minor = Integer($2, 10)
          patch = 0
        else
          raise ArgumentError, "invalid version string: #{str.inspect}"
        end

        validate_component(major, :major)
        validate_component(minor, :minor)
        validate_component(patch, :patch)

        new(major:, minor:, patch:)
      end

      # Create MODVersion from three integers
      #
      # @param major [Integer] major version number (0-255)
      # @param minor [Integer] minor version number (0-255)
      # @param patch [Integer] patch version number (0-255)
      # @return [MODVersion]
      # @raise [ArgumentError] if any component is out of range
      def self.from_numbers(major, minor, patch)
        validate_component(major, :major)
        validate_component(minor, :minor)
        validate_component(patch, :patch)

        new(major:, minor:, patch:)
      end

      private_class_method :new, :[]

      # Convert to string representation
      #
      # @return [String] Version string in format "X.Y.Z"
      def to_s = "#{major}.#{minor}.#{patch}"

      # Convert to array of integers
      #
      # @return [Array<Integer>] Array containing [major, minor, patch]
      def to_a = [major, minor, patch].freeze

      # Compare with another MODVersion
      #
      # @param other [MODVersion] Version to compare with
      # @return [Integer, nil] -1, 0, 1 for less than, equal to, greater than; nil if not comparable
      def <=>(other)
        return nil unless other.is_a?(MODVersion)

        to_a <=> other.to_a
      end
    end
  end
end
