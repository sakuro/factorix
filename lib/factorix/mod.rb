# frozen_string_literal: true

module Factorix
  MOD = Data.define(:name)

  # Represents a local MOD
  #
  # This class encapsulates a MOD's name and provides utility methods
  # for MOD identification and comparison.
  class MOD
    include Comparable

    # @!attribute [r] name
    #   @return [String] the name of the MOD

    # Expansion MOD names
    EXPANSION_MODS = %w[space-age quality elevated-rails].freeze
    private_constant :EXPANSION_MODS

    # Check if this MOD is the base MOD
    #
    # @return [Boolean] true if this MOD is the base MOD
    # @note The check is case-sensitive, only "base" (not "BASE" or "Base") is considered the base MOD
    def base?
      name == "base"
    end

    # Check if this MOD is an expansion MOD
    #
    # @return [Boolean] true if this MOD is an expansion MOD (space-age, quality, or elevated-rails)
    # @note The check is case-sensitive
    def expansion?
      EXPANSION_MODS.include?(name)
    end

    # Return the name of the MOD
    #
    # @return [String] the name of the MOD
    def to_s
      name
    end

    # Compare this MOD with another MOD by name
    #
    # @param other [MOD] the other MOD
    # @return [Integer] -1 if this MOD precedes the other, 0 if they are equal, 1 if this MOD follows the other
    # @note Comparison is case-sensitive for MOD names.
    # @note The base MOD (exactly "base", case-sensitive) always comes before any other MOD.
    def <=>(other)
      return nil unless other.is_a?(MOD)

      if base?
        other.base? ? 0 : -1
      elsif other.base?
        1
      else
        name <=> other.name
      end
    end
  end
end
