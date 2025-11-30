# frozen_string_literal: true

module Factorix
  module API
    Category = Data.define(:value, :name, :description)

    # Category object from MOD Portal API
    #
    # Represents a MOD category with value, name, and description.
    # Uses flyweight pattern - same category value returns same instance.
    #
    # @see https://wiki.factorio.com/Mod_details_API#Category
    class Category
      # @!attribute [r] value
      #   @return [String] category value (e.g., "content", "utilities", "" for no category)
      # @!attribute [r] name
      #   @return [String] human-readable category name (e.g., "Content", "Utilities")
      # @!attribute [r] description
      #   @return [String] category description

      # Predefined category instances
      NO_CATEGORY = new(value: "", name: "No category", description: "Unassigned category")
      private_constant :NO_CATEGORY
      CONTENT = new(value: "content", name: "Content", description: "Mods introducing new content into the game")
      private_constant :CONTENT
      OVERHAUL = new(value: "overhaul", name: "Overhaul", description: "Large total conversion mods")
      private_constant :OVERHAUL
      TWEAKS = new(value: "tweaks", name: "Tweaks", description: "Small changes concerning balance, gameplay, or graphics")
      private_constant :TWEAKS
      UTILITIES = new(value: "utilities", name: "Utilities", description: "Providing the player with new tools or adjusting the game interface")
      private_constant :UTILITIES
      SCENARIOS = new(value: "scenarios", name: "Scenarios", description: "Scenarios, maps, and puzzles")
      private_constant :SCENARIOS
      MOD_PACKS = new(value: "mod-packs", name: "Mod packs", description: "Collections of mods with tweaks to make them work together")
      private_constant :MOD_PACKS
      LOCALIZATIONS = new(value: "localizations", name: "Localizations", description: "Translations for other mods")
      private_constant :LOCALIZATIONS
      INTERNAL = new(value: "internal", name: "Internal", description: "Lua libraries for use by other mods")
      private_constant :INTERNAL

      # Lookup table for flyweight pattern
      CATEGORIES = {
        "" => NO_CATEGORY,
        "no-category" => NO_CATEGORY,
        "content" => CONTENT,
        "overhaul" => OVERHAUL,
        "tweaks" => TWEAKS,
        "utilities" => UTILITIES,
        "scenarios" => SCENARIOS,
        "mod-packs" => MOD_PACKS,
        "localizations" => LOCALIZATIONS,
        "internal" => INTERNAL
      }.freeze
      private_constant :CATEGORIES

      # Get Category instance for the given value
      #
      # Returns predefined instance for known categories (flyweight pattern).
      # Raises an error for unknown category values.
      #
      # @param value [String] category value
      # @return [Category] Category instance
      # @raise [KeyError] if category value is unknown
      def self.for(value) = CATEGORIES.fetch(value.to_s)

      private_class_method :new, :[]
    end
  end
end
