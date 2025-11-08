# frozen_string_literal: true

module Factorix
  module SerDes
    # Represent a 4-component game version number (major.minor.patch-build)
    #
    # This class represents Factorio's game version format, which uses
    # 64 bits (4 x 16-bit unsigned integers) to store version information.
    class GameVersion
      include Comparable

      UINT16_MAX = (2**16) - 1
      private_constant :UINT16_MAX

      # Create a new GameVersion instance
      #
      # @param args [Array] Either a version string "X.Y.Z-B" or 4 integers representing major, minor, patch, build
      # @return [GameVersion] New GameVersion instance
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
      #
      # @return [String] Version string in format "X.Y.Z-B"
      def to_s
        "%d.%d.%d-%d" % @version
      end

      # Convert to array of integers
      #
      # @return [Array<Integer>] Array containing [major, minor, patch, build]
      def to_a
        @version.dup.freeze
      end

      # Compare with another GameVersion
      #
      # @param other [GameVersion] Version to compare with
      # @return [Integer, nil] -1, 0, 1 for less than, equal to, greater than; nil if not comparable
      def <=>(other)
        @version <=> other.version
      end
    end
  end
end
