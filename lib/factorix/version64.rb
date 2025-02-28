# frozen_string_literal: true

module Factorix
  # Represent a 4-component version number (major.minor.patch-build)
  class Version64
    include Comparable

    UINT16_MAX = (2**16) - 1
    private_constant :UINT16_MAX

    # Create a new Version64 instance
    #
    # @param args [Array] Either a version string "X.Y.Z-B" or 4 integers representing major, minor, patch, build
    # @return [Version64] New Version64 instance
    # @raise [ArgumentError] If the arguments are invalid
    def initialize(*args)
      case args
      in [String] if /\A(\d+)\.(\d+)\.(\d+)(?:-(\d+))?\z/ =~ args[0]
        @version = [Integer($1), Integer($2), Integer($3), $4.nil? ? 0 : Integer($4)]
      in [Integer, Integer, Integer, Integer] if args.all? {|e| e.is_a?(Numeric) && e.integer? && e.between?(0, UINT16_MAX) }
        @version = args
      else
        raise ArgumentError, "expect version string or 4-tuple: %p" % [args]
      end
      @version.freeze
      freeze
    end

    class << self
      alias [] new
    end

    protected attr_reader :version

    # Convert to string representation
    # @return [String] Version string in format "X.Y.Z-B"
    def to_s = "%d.%d.%d-%d" % @version

    # Convert to array of integers
    # @return [Array<Integer>] Array containing [major, minor, patch, build]
    def to_a = @version.dup.freeze

    # Compare with another Version64
    # @param other [Version64] Version to compare with
    # @return [Integer, nil] -1, 0, 1 for less than, equal to, greater than; nil if not comparable
    def <=>(other) = @version <=> other.version
  end
end
