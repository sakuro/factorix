# frozen_string_literal: true

module Factorix
  # Define MODDependency as an immutable data class
  MODDependency = Data.define(:mod, :type, :version_requirement)

  # Represents a single MOD dependency
  #
  # This class encapsulates a MOD dependency with its type (required, optional, etc.)
  # and optional version requirement.
  #
  # @!attribute [r] mod
  #   @return [MOD] The dependent MOD
  # @!attribute [r] type
  #   @return [Symbol] Type of dependency (:required, :optional, :hidden, :incompatible, :load_neutral)
  # @!attribute [r] version_requirement
  #   @return [Types::MODVersionRequirement, nil] Version requirement (nil if no requirement)
  #
  # @example Creating dependencies
  #   # Required dependency on base MOD
  #   base_mod = MOD[name: "base"]
  #   dep1 = MODDependency[mod: base_mod, type: :required, version_requirement: nil]
  #
  #   # Optional dependency with version requirement
  #   some_mod = MOD[name: "some-mod"]
  #   requirement = Types::MODVersionRequirement[operator: ">=", version: Types::MODVersion.from_string("1.2.0")]
  #   dep2 = MODDependency[mod: some_mod, type: :optional, version_requirement: requirement]
  #
  #   # Incompatible MOD
  #   bad_mod = MOD[name: "bad-mod"]
  #   dep3 = MODDependency[mod: bad_mod, type: :incompatible, version_requirement: nil]
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
    # @param mod [MOD] The dependent MOD
    # @param type [Symbol] Type of dependency (:required, :optional, :hidden, :incompatible, :load_neutral)
    # @param version_requirement [Types::MODVersionRequirement, nil] Version requirement (nil if no requirement)
    # @return [MODDependency]
    # @raise [ArgumentError] if mod is not a MOD instance
    # @raise [ArgumentError] if type is not valid
    # @raise [ArgumentError] if version_requirement is not nil or MODVersionRequirement
    def initialize(mod:, type:, version_requirement: nil)
      unless mod.is_a?(MOD)
        raise ArgumentError, "mod must be a MOD instance, got #{mod.class}"
      end

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

      result += mod.name
      result += " #{version_requirement}" if version_requirement
      result
    end
  end
end
