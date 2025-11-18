# frozen_string_literal: true

require "delegate"

module Factorix
  module Types
    # Signed integer wrapper
    #
    # This class wraps an Integer value to indicate it was originally stored
    # as a signed integer (Type 6) in Factorio's Property Tree format.
    #
    # @example Creating a signed integer
    #   value = SignedInteger.new(42)
    #   value + 1  # => 43 (behaves like Integer)
    #
    # @example Negative values are allowed
    #   value = SignedInteger.new(-5)
    class SignedInteger < SimpleDelegator
      # Create a new SignedInteger
      #
      # @param value [Integer] The integer value
      # @raise [ArgumentError] If value is not an Integer
      def initialize(value)
        raise ArgumentError, "value must be an Integer" unless value.is_a?(Integer)

        super
      end

      # Get the underlying integer value
      #
      # @return [Integer] The wrapped integer value
      def value = __getobj__

      # Compare with another SignedInteger or Integer
      #
      # @param other [SignedInteger, Integer] The value to compare with
      # @return [Boolean] True if equal
      def ==(other)
        case other
        when SignedInteger
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
      def hash = [value, :signed].hash

      # Check if equal (alias for ==)
      alias eql? ==

      # String representation
      #
      # @return [String] String representation
      def inspect = "#<Factorix::Types::SignedInteger:0x%016x value=#{value}>" % object_id
    end
  end
end
