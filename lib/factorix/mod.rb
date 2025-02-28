# frozen_string_literal: true

module Factorix
  # Represent MOD
  Mod = Data.define(:name) {
    include Comparable

    # @!attribute [r] name
    #   @return [String] the name of the MOD

    # Return true if this MOD is the base MOD
    # @return [Boolean] true if this MOD is the base MOD
    # @note The check is case-sensitive, only "base" (not "BASE" or "Base") is considered the base MOD
    def base? = name == "base"

    # Return the name of the MOD
    # @return [String] the name of the MOD
    def to_s = name

    # Compare this MOD with another MOD by name.
    # @param other [Mod] the other MOD
    # @return [Integer] -1 if this MOD precedes the other, 0 if they are equal, 1 if this MOD follows the other
    # @note Comparison is case-sensitive for MOD names.
    # @note The base MOD (exactly "base", case-sensitive) always comes before any other MOD.
    def <=>(other) = (base? && (other.base? ? 0 : -1)) || (other.base? ? 1 : name <=> other.name)
  }
end
