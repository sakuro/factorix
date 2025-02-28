# frozen_string_literal: true

module Factorix
  # Represent a 3-component version number (major.minor.patch)
  class Version24
    include Comparable

    UINT8_MAX = (2**8) - 1
    private_constant :UINT8_MAX

    # Create a new Version24 instance
    #
    # @param args [Array] Either a version string "X.Y.Z" or 3 integers representing major, minor, patch
    # @return [Version24] New Version24 instance
    # @raise [ArgumentError] If the arguments are invalid
    def initialize(*args)
      case args
      in [String] if /\A(\d+)\.(\d+)\.(\d+)\z/ =~ args[0]
        @version = [Integer($1), Integer($2), Integer($3)]
      in [Integer, Integer, Integer] if args.all? {|e| e.is_a?(Numeric) && e.integer? && e.between?(0, UINT8_MAX) }
        @version = args
      else
        raise ArgumentError, "expect version string or 3-tuple: %p" % [args]
      end
      @version.freeze
      freeze
    end

    class << self
      alias [] new
    end

    protected attr_reader :version

    # Convert to string representation
    # @return [String] Version string in format "X.Y.Z"
    def to_s = "%d.%d.%d" % @version

    # Convert to array of integers
    # @return [Array<Integer>] Array containing [major, minor, patch]
    def to_a = @version.dup.freeze

    # Compare with another Version24
    # @param other [Version24] Version to compare with
    # @return [Integer, nil] -1, 0, 1 for less than, equal to, greater than; nil if not comparable
    def <=>(other) = @version <=> other.version
  end
end
