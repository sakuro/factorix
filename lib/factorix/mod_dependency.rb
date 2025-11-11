# frozen_string_literal: true

module Factorix
  # Define MODDependency as an immutable data class
  MODDependency = Data.define(:mod_name, :type, :version_requirement)

  # Represents a single MOD dependency
  #
  # This class encapsulates a MOD dependency with its type (required, optional, etc.)
  # and optional version requirement.
  #
  # @example Creating dependencies
  #   # Required dependency on base MOD
  #   dep1 = MODDependency.new(mod_name: "base", type: :required, version_requirement: nil)
  #
  #   # Optional dependency with version requirement
  #   requirement = Types::MODVersionRequirement.new(operator: ">=", version: Types::MODVersion.from_string("1.2.0"))
  #   dep2 = MODDependency.new(mod_name: "some-mod", type: :optional, version_requirement: requirement)
  #
  #   # Incompatible MOD
  #   dep3 = MODDependency.new(mod_name: "bad-mod", type: :incompatible, version_requirement: nil)
  class MODDependency
    # Dependency type constants
    REQUIRED = :required
    public_constant :REQUIRED
    OPTIONAL = :optional
    public_constant :OPTIONAL
    HIDDEN_OPTIONAL = :hidden
    public_constant :HIDDEN_OPTIONAL
    INCOMPATIBLE = :incompatible
    public_constant :INCOMPATIBLE
    LOAD_NEUTRAL = :load_neutral
    public_constant :LOAD_NEUTRAL

    VALID_TYPES = [REQUIRED, OPTIONAL, HIDDEN_OPTIONAL, INCOMPATIBLE, LOAD_NEUTRAL].freeze
    private_constant :VALID_TYPES

    # Create a new MODDependency
    #
    # @param mod_name [String] Name of the dependent MOD
    # @param type [Symbol] Type of dependency (:required, :optional, :hidden, :incompatible, :load_neutral)
    # @param version_requirement [Types::MODVersionRequirement, nil] Version requirement (nil if no requirement)
    # @return [MODDependency]
    # @raise [ArgumentError] if type is not valid
    # @raise [ArgumentError] if version_requirement is not nil or MODVersionRequirement
    def initialize(mod_name:, type:, version_requirement: nil)
      unless VALID_TYPES.include?(type)
        raise ArgumentError, "Invalid dependency type: #{type}. Must be one of: #{VALID_TYPES.join(", ")}"
      end

      if version_requirement && !version_requirement.is_a?(Types::MODVersionRequirement)
        raise ArgumentError, "version_requirement must be a MODVersionRequirement or nil, got #{version_requirement.class}"
      end

      super
    end

    # Check if this is a required dependency
    #
    # @return [Boolean] true if dependency is required
    def required?
      type == REQUIRED
    end

    # Check if this is an optional dependency (including hidden optional)
    #
    # @return [Boolean] true if dependency is optional or hidden optional
    def optional?
      type == OPTIONAL || type == HIDDEN_OPTIONAL
    end

    # Check if this is an incompatible (conflicting) dependency
    #
    # @return [Boolean] true if dependency is incompatible
    def incompatible?
      type == INCOMPATIBLE
    end

    # Check if this dependency does not affect load order
    #
    # @return [Boolean] true if dependency is load-neutral
    def load_neutral?
      type == LOAD_NEUTRAL
    end

    # Check if a given version satisfies this dependency's version requirement
    #
    # @param version [Types::MODVersion] Version to check
    # @return [Boolean] true if version requirement is satisfied, or true if no requirement exists
    def satisfied_by?(version)
      return true unless version_requirement

      version_requirement.satisfied_by?(version)
    end

    # Return string representation of the dependency
    #
    # @return [String] String representation (e.g., "? some-mod >= 1.2.0")
    def to_s
      result = case type
               when REQUIRED then ""
               when OPTIONAL then "? "
               when HIDDEN_OPTIONAL then "(?) "
               when INCOMPATIBLE then "! "
               when LOAD_NEUTRAL then "~ "
               else
                 raise ArgumentError, "Unexpected dependency type: #{type}"
               end

      result += mod_name
      result += " #{version_requirement}" if version_requirement
      result
    end
  end
end
