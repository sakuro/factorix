# frozen_string_literal: true

module Factorix
  # Represent MOD
  Mod = Data.define(:name) {
    include Comparable

    # @!attribute [r] name
    #   @return [String] the name of the mod

    # Return true if this mod is the base mod
    # @return [Boolean] true if this mod is the base mod
    # @note The check is case-sensitive, only "base" (not "BASE" or "Base") is considered the base mod
    def base? = name == "base"

    # Return the name of the mod
    # @return [String] the name of the mod
    def to_s = name

    # Compare this mod with another mod by name.
    # @param other [Mod] the other mod
    # @return [Integer] -1 if this mod precedes the other, 0 if they are equal, 1 if this mod follows the other
    # @note Comparison is case-sensitive for mod names.
    # @note The base mod (exactly "base", case-sensitive) always comes before any other mod.
    def <=>(other) = (base? && (other.base? ? 0 : -1)) || (other.base? ? 1 : name <=> other.name)
  }
end
