# frozen_string_literal: true

module Factorix
  GameVersion = Data.define(:major, :minor, :patch, :build)

  # Represent a 4-component game version number (major.minor.patch-build)
  #
  # This class represents Factorio's game version format, which uses
  # 64 bits (4 x 16-bit unsigned integers) to store version information.
  #
  # @see https://wiki.factorio.com/Version_string_format
  class GameVersion
    include Comparable

    # @!attribute [r] major
    #   @return [Integer] major version number (0-65535)
    # @!attribute [r] minor
    #   @return [Integer] minor version number (0-65535)
    # @!attribute [r] patch
    #   @return [Integer] patch version number (0-65535)
    # @!attribute [r] build
    #   @return [Integer] build version number (0-65535)

    UINT16_MAX = (2**16) - 1
    private_constant :UINT16_MAX

    class << self
      private def validate_component(value, name)
        raise VersionParseError, "#{name} must be an Integer, got #{value.class}" unless value.is_a?(Integer)
        return if value.between?(0, UINT16_MAX)

        raise VersionParseError, "#{name} must be between 0 and #{UINT16_MAX}, got #{value}"
      end
    end

    # Create GameVersion from version string "X.Y.Z-B" or "X.Y.Z"
    #
    # @param str [String] version string in "X.Y.Z-B" format (build defaults to 0 if omitted)
    # @return [GameVersion]
    # @raise [VersionParseError] if string format is invalid
    def self.from_string(str)
      unless /\A(\d+)\.(\d+)\.(\d+)(?:-(\d+))?\z/ =~ str
        raise VersionParseError, "invalid version string: #{str.inspect}"
      end

      major = Integer($1)
      minor = Integer($2)
      patch = Integer($3)
      build = $4.nil? ? 0 : Integer($4)

      validate_component(major, :major)
      validate_component(minor, :minor)
      validate_component(patch, :patch)
      validate_component(build, :build)

      new(major:, minor:, patch:, build:)
    end

    # Create GameVersion from four integers
    #
    # @param major [Integer] major version number (0-65535)
    # @param minor [Integer] minor version number (0-65535)
    # @param patch [Integer] patch version number (0-65535)
    # @param build [Integer] build version number (0-65535, defaults to 0)
    # @return [GameVersion]
    # @raise [VersionParseError] if any component is out of range
    def self.from_numbers(major, minor, patch, build=0)
      validate_component(major, :major)
      validate_component(minor, :minor)
      validate_component(patch, :patch)
      validate_component(build, :build)

      new(major:, minor:, patch:, build:)
    end

    private_class_method :new, :[]

    # Convert to string representation
    #
    # @return [String] Version string in format "X.Y.Z-B" or "X.Y.Z" if build is 0
    def to_s = build.zero? ? "#{major}.#{minor}.#{patch}" : "#{major}.#{minor}.#{patch}-#{build}"

    # Convert to array of integers
    #
    # @return [Array<Integer>] Array containing [major, minor, patch, build]
    def to_a = [major, minor, patch, build].freeze

    # Compare with another GameVersion
    #
    # @param other [GameVersion] Version to compare with
    # @return [Integer, nil] -1, 0, 1 for less than, equal to, greater than; nil if not comparable
    def <=>(other)
      return nil unless other.is_a?(GameVersion)

      to_a <=> other.to_a
    end
  end
end
