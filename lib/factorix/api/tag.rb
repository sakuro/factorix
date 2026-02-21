# frozen_string_literal: true

module Factorix
  module API
    Tag = Data.define(:value, :name, :description)

    # Tag object from MOD Portal API
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
      TRANSPORTATION = new(value: "transportation", name: "Transportation", description: "Transportation of the player, be it vehicles or teleporters.")
      private_constant :TRANSPORTATION
      LOGISTICS = new(value: "logistics", name: "Logistics", description: "Augmented or new ways of transporting materials - belts, inserters, pipes!")
      private_constant :LOGISTICS
      TRAINS = new(value: "trains", name: "Trains", description: "Trains are great, but what if they could do even more?")
      private_constant :TRAINS
      COMBAT = new(value: "combat", name: "Combat", description: "New ways to deal with enemies, be it attack or defense.")
      private_constant :COMBAT
      ARMOR = new(value: "armor", name: "Armor", description: "Armors or armor equipment.")
      private_constant :ARMOR
      ENEMIES = new(value: "enemies", name: "Enemies", description: "Changes to enemies or entirely new enemies to deal with.")
      private_constant :ENEMIES
      CHARACTER = new(value: "character", name: "Character", description: "Changes to the player's in-game appearance.")
      private_constant :CHARACTER
      ENVIRONMENT = new(value: "environment", name: "Environment", description: "Map generation and terrain modification.")
      private_constant :ENVIRONMENT
      PLANETS = new(value: "planets", name: "Planets", description: "New places to build more factories.")
      private_constant :PLANETS
      MINING = new(value: "mining", name: "Mining", description: "New ores and resources as well as machines.")
      private_constant :MINING
      FLUIDS = new(value: "fluids", name: "Fluids", description: "Things related to oil and other fluids.")
      private_constant :FLUIDS
      LOGISTIC_NETWORK = new(value: "logistic-network", name: "Logistics Network", description: "Related to roboports and logistic robots")
      private_constant :LOGISTIC_NETWORK
      CIRCUIT_NETWORK = new(value: "circuit-network", name: "Circuit network", description: "Entities which interact with the circuit network.")
      private_constant :CIRCUIT_NETWORK
      MANUFACTURING = new(value: "manufacturing", name: "Manufacture", description: "Furnaces, assembling machines, production chains")
      private_constant :MANUFACTURING
      POWER = new(value: "power", name: "Power Production", description: "Changes to power production and distribution.")
      private_constant :POWER
      STORAGE = new(value: "storage", name: "Storage", description: "More than just chests.")
      private_constant :STORAGE
      BLUEPRINTS = new(value: "blueprints", name: "Blueprints", description: "Change blueprint behavior.")
      private_constant :BLUEPRINTS
      CHEATS = new(value: "cheats", name: "Cheats", description: "Play it your way.")
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

      # @return [Array<String>] all tag identifiers
      def self.identifiers = TAGS.keys

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
