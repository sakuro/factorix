# frozen_string_literal: true

module Factorix
  module Types
    Tag = Data.define(:value, :name, :description)

    # Tag object from Mod Portal API
    #
    # Represents a MOD tag with value, name, and description.
    # Uses flyweight pattern - same tag value returns same instance.
    #
    # @see https://wiki.factorio.com/Mod_portal_API#Tags
    class Tag
      # @!attribute [r] value
      #   @return [String] tag value (e.g., "transportation", "logistics")
      # @!attribute [r] name
      #   @return [String] human-readable tag name (e.g., "Transportation", "Logistics")
      # @!attribute [r] description
      #   @return [String] tag description

      # Predefined tag instances
      TRANSPORTATION = new(
        value: "transportation",
        name: "Transportation",
        description: "Transportation of the player, be it vehicles or teleporters."
      )
      LOGISTICS = new(
        value: "logistics",
        name: "Logistics",
        description: "Augmented or new ways of transporting materials - belts, inserters, pipes!"
      )
      TRAINS = new(
        value: "trains",
        name: "Trains",
        description: "Trains are great, but what if they could do even more?"
      )
      COMBAT = new(
        value: "combat",
        name: "Combat",
        description: "New ways to deal with enemies, be it attack or defense."
      )
      ARMOR = new(
        value: "armor",
        name: "Armor",
        description: "Armors or armor equipment."
      )
      ENEMIES = new(
        value: "enemies",
        name: "Enemies",
        description: "Changes to enemies or entirely new enemies to deal with."
      )
      CHARACTER = new(
        value: "character",
        name: "Character",
        description: "Changes to the player's in-game appearance."
      )
      ENVIRONMENT = new(
        value: "environment",
        name: "Environment",
        description: "Map generation and terrain modification."
      )
      PLANETS = new(
        value: "planets",
        name: "Planets",
        description: "New places to build more factories."
      )
      MINING = new(
        value: "mining",
        name: "Mining",
        description: "New ores and resources as well as machines."
      )
      FLUIDS = new(
        value: "fluids",
        name: "Fluids",
        description: "Things related to oil and other fluids."
      )
      LOGISTIC_NETWORK = new(
        value: "logistic-network",
        name: "Logistics Network",
        description: "Related to roboports and logistic robots"
      )
      CIRCUIT_NETWORK = new(
        value: "circuit-network",
        name: "Circuit network",
        description: "Entities which interact with the circuit network."
      )
      MANUFACTURING = new(
        value: "manufacturing",
        name: "Manufacture",
        description: "Furnaces, assembling machines, production chains"
      )
      POWER = new(
        value: "power",
        name: "Power Production",
        description: "Changes to power production and distribution."
      )
      STORAGE = new(
        value: "storage",
        name: "Storage",
        description: "More than just chests."
      )
      BLUEPRINTS = new(
        value: "blueprints",
        name: "Blueprints",
        description: "Change blueprint behavior."
      )
      CHEATS = new(
        value: "cheats",
        name: "Cheats",
        description: "Play it your way."
      )
      private_constant :TRANSPORTATION
      private_constant :LOGISTICS
      private_constant :TRAINS
      private_constant :COMBAT
      private_constant :ARMOR
      private_constant :ENEMIES
      private_constant :CHARACTER
      private_constant :ENVIRONMENT
      private_constant :PLANETS
      private_constant :MINING
      private_constant :FLUIDS
      private_constant :LOGISTIC_NETWORK
      private_constant :CIRCUIT_NETWORK
      private_constant :MANUFACTURING
      private_constant :POWER
      private_constant :STORAGE
      private_constant :BLUEPRINTS
      private_constant :CHEATS

      # Lookup table for flyweight pattern
      TAGS = {
        "transportation" => TRANSPORTATION,
        "logistics" => LOGISTICS,
        "trains" => TRAINS,
        "combat" => COMBAT,
        "armor" => ARMOR,
        "enemies" => ENEMIES,
        "character" => CHARACTER,
        "environment" => ENVIRONMENT,
        "planets" => PLANETS,
        "mining" => MINING,
        "fluids" => FLUIDS,
        "logistic-network" => LOGISTIC_NETWORK,
        "circuit-network" => CIRCUIT_NETWORK,
        "manufacturing" => MANUFACTURING,
        "power" => POWER,
        "storage" => STORAGE,
        "blueprints" => BLUEPRINTS,
        "cheats" => CHEATS
      }.freeze
      private_constant :TAGS

      # Get Tag instance for the given value
      #
      # Returns predefined instance for known tags (flyweight pattern).
      # Raises an error for unknown tag values.
      #
      # @param value [String] tag value
      # @return [Tag] Tag instance
      # @raise [KeyError] if tag value is unknown
      def self.for(value) = TAGS.fetch(value.to_s)

      private_class_method :new, :[]
    end
  end
end
