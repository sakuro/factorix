# frozen_string_literal: true

module Factorix
  # Class representing a mod
  Mod = Data.define(:name) {
    include Comparable

    # Return true if this mod is the base mod
    # @return [Boolean] true if this mod is the base mod
    def base? = name == "base"

    # Return the name of the mod
    # @return [String] the name of the mod
    def to_s = name

    # Compare this mod with another mod
    # @param other [Mod] the other mod
    # @return [Integer] -1 if this mod precedes the other, 0 if they are equal, 1 if this mod follows the other
    def <=>(other) = (base? && (other.base? ? 0 : -1)) || (other.base? ? 1 : name.casecmp(other.name))
  }
end
