# frozen_string_literal: true

module Factorix
  module Dependency
    # Represents a dependency edge in the dependency graph
    #
    # Each edge represents a dependency relationship from one MOD (dependent)
    # to another MOD (dependency). The edge type indicates the nature of the
    # relationship (required, optional, incompatible, etc.).
    class Edge
      attr_reader :from_mod              # MOD object (the dependent)
      attr_reader :to_mod                # MOD object (the dependency)
      attr_reader :type                  # Symbol - dependency type
      attr_reader :version_requirement   # Types::MODVersionRequirement or nil

      # Dependency types (from Factorix::Dependency::Entry)
      REQUIRED = Entry::REQUIRED
      OPTIONAL = Entry::OPTIONAL
      HIDDEN_OPTIONAL = Entry::HIDDEN_OPTIONAL
      INCOMPATIBLE = Entry::INCOMPATIBLE
      LOAD_NEUTRAL = Entry::LOAD_NEUTRAL
      public_constant :REQUIRED, :OPTIONAL, :HIDDEN_OPTIONAL, :INCOMPATIBLE, :LOAD_NEUTRAL

      # Create a new dependency edge
      #
      # @param from_mod [Factorix::MOD] The dependent MOD
      # @param to_mod [Factorix::MOD] The dependency MOD
      # @param type [Symbol] The dependency type (:required, :optional, :hidden, :incompatible, :load_neutral)
      # @param version_requirement [Factorix::Types::MODVersionRequirement, nil] Version requirement (optional)
      def initialize(from_mod:, to_mod:, type:, version_requirement: nil)
        @from_mod = from_mod
        @to_mod = to_mod
        @type = type
        @version_requirement = version_requirement
      end

      # Check if this is a required dependency
      #
      # @return [Boolean]
      def required? = @type == REQUIRED

      # Check if this is an optional dependency
      #
      # @return [Boolean]
      def optional? = @type == OPTIONAL || @type == HIDDEN_OPTIONAL

      # Check if this is a hidden optional dependency
      #
      # @return [Boolean]
      def hidden_optional? = @type == HIDDEN_OPTIONAL

      # Check if this is an incompatibility relationship
      #
      # @return [Boolean]
      def incompatible? = @type == INCOMPATIBLE

      # Check if this is a load-neutral dependency
      #
      # @return [Boolean]
      def load_neutral? = @type == LOAD_NEUTRAL

      # Check if the given version satisfies this edge's version requirement
      #
      # @param version [Factorix::Types::MODVersion] The version to check
      # @return [Boolean] true if satisfied or no requirement exists
      def satisfied_by?(version)
        return true unless @version_requirement

        @version_requirement.satisfied_by?(version)
      end

      # String representation of the edge
      #
      # @return [String]
      def to_s
        requirement_str = @version_requirement ? " #{@version_requirement}" : ""
        "#{@from_mod} --[#{@type}#{requirement_str}]--> #{@to_mod}"
      end

      # Detailed inspection string
      #
      # @return [String]
      def inspect = "#<#{self.class.name} #{self}>"
    end
  end
end
