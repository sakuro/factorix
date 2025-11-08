# frozen_string_literal: true

module Factorix
  module SerDes
    # Represent a 3-component MOD version number (major.minor.patch)
    #
    # This class represents Factorio's MOD version format, which uses
    # 24 bits (3 x 8-bit unsigned integers) to store version information.
    class MODVersion
      include Comparable

      UINT8_MAX = (2**8) - 1
      private_constant :UINT8_MAX

      # Create a new MODVersion instance
      #
      # @param args [Array] Either a version string "X.Y.Z" or 3 integers representing major, minor, patch
      # @return [MODVersion] New MODVersion instance
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
      #
      # @return [String] Version string in format "X.Y.Z"
      def to_s
        "%d.%d.%d" % @version
      end

      # Convert to array of integers
      #
      # @return [Array<Integer>] Array containing [major, minor, patch]
      def to_a
        @version.dup.freeze
      end

      # Compare with another MODVersion
      #
      # @param other [MODVersion] Version to compare with
      # @return [Integer, nil] -1, 0, 1 for less than, equal to, greater than; nil if not comparable
      def <=>(other)
        @version <=> other.version
      end
    end
  end
end
