# frozen_string_literal: true

module Factorix
  module Types
    # Define MODVersionRequirement as an immutable data class
    MODVersionRequirement = Data.define(:operator, :version)

    # Represents a MOD version requirement with an operator and version
    #
    # This class is used in MOD dependencies to specify version constraints.
    # It supports the following comparison operators: <, <=, =, >=, >
    #
    # @example Creating a version requirement
    #   requirement = MODVersionRequirement.new(operator: ">=", version: MODVersion.from_string("1.2.0"))
    #   requirement.satisfied_by?(MODVersion.from_string("1.3.0")) # => true
    #   requirement.satisfied_by?(MODVersion.from_string("1.1.0")) # => false
    class MODVersionRequirement
      # Valid comparison operators
      VALID_OPERATORS = ["<", "<=", "=", ">=", ">"].freeze
      private_constant :VALID_OPERATORS

      # Create a new MODVersionRequirement
      #
      # @param operator [String] Comparison operator (<, <=, =, >=, >)
      # @param version [MODVersion] Version to compare against
      # @return [MODVersionRequirement]
      # @raise [ArgumentError] if operator is not valid
      # @raise [ArgumentError] if version is not a MODVersion
      def initialize(operator:, version:)
        unless VALID_OPERATORS.include?(operator)
          raise ArgumentError, "Invalid operator: #{operator}. Must be one of: #{VALID_OPERATORS.join(", ")}"
        end

        unless version.is_a?(MODVersion)
          raise ArgumentError, "version must be a MODVersion, got #{version.class}"
        end

        super
      end

      # Check if a given version satisfies this requirement
      #
      # @param mod_version [MODVersion] Version to check
      # @return [Boolean] true if the version satisfies the requirement
      def satisfied_by?(mod_version)
        case operator
        when "="
          mod_version == version
        when ">="
          mod_version >= version
        when ">"
          mod_version > version
        when "<="
          mod_version <= version
        when "<"
          mod_version < version
        else
          raise ArgumentError, "Unexpected operator: #{operator}"
        end
      end

      # String representation of the requirement
      #
      # @return [String] String representation (e.g., ">= 1.2.0")
      def to_s
        "#{operator} #{version}"
      end
    end
  end
end
