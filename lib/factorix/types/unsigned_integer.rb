# frozen_string_literal: true

require "delegate"

module Factorix
  module Types
    # Unsigned integer wrapper
    #
    # This class wraps a non-negative Integer value to indicate it was originally
    # stored as an unsigned integer (Type 7) in Factorio's Property Tree format.
    #
    # @example Creating an unsigned integer
    #   value = UnsignedInteger.new(42)
    #   value + 1  # => 43 (behaves like Integer)
    #
    # @example Negative values raise an error
    #   UnsignedInteger.new(-5)  # => ArgumentError
    class UnsignedInteger < SimpleDelegator
      # Create a new UnsignedInteger
      #
      # @param value [Integer] The integer value (must be non-negative)
      # @raise [ArgumentError] If value is not an Integer
      # @raise [ArgumentError] If value is negative
      def initialize(value)
        raise ArgumentError, "value must be an Integer" unless value.is_a?(Integer)
        raise ArgumentError, "value must be non-negative" if value.negative?

        super
      end

      # Get the underlying integer value
      #
      # @return [Integer] The wrapped integer value
      def value = __getobj__

      # Compare with another UnsignedInteger or Integer
      #
      # @param other [UnsignedInteger, Integer] The value to compare with
      # @return [Boolean] True if equal
      def ==(other)
        case other
        when UnsignedInteger
          value == other.value
        when Integer
          value == other
        else
          false
        end
      end

      # Hash code for use in Hash keys
      #
      # @return [Integer] Hash code
      def hash = [value, :unsigned].hash

      # Check if equal (alias for ==)
      alias eql? ==

      # String representation
      #
      # @return [String] String representation
      def inspect = "#<Factorix::Types::UnsignedInteger:0x%016x value=#{value}>" % object_id
    end
  end
end
