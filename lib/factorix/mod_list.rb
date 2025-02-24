# frozen_string_literal: true

require "json"
require_relative "errors"

module Factorix
  # Represents the list of mods and their enabled status.
  class ModList
    include Enumerable

    # Raised when a MOD is not found.
    class ModNotInListError < Factorix::ModNotFoundError
      def initialize(mod)
        super("MOD not in the list: #{mod}")
      end
    end

    # Load the mod list from the given file.
    # @param from [Pathname] the path to the file to load the mod list from.
    def self.load(from: Factorix::Runtime.runtime.mod_list_path)
      raw_data = JSON.parse(from.read, symbolize_names: true)
      new(raw_data[:mods].to_h {|e| [Mod[name: e[:name]], e[:enabled]] })
    end

    # Initialize the mod list.
    # @param mods [Hash{Factorix::Mod => Boolean}] the mods and their enabled status.
    def initialize(mods={})
      @mods = {Mod[name: "base"] => true}
      mods.each do |mod, enabled|
        next if mod.base?

        @mods[mod] = enabled
      end
    end

    # Save the mod list to the given file.
    # @param to [Pathname] the path to the file to save the mod list to.
    def save(to: Factorix::Runtime.runtime.mod_list_path)
      to.write(JSON.pretty_generate({mods: @mods.map {|mod, enabled| {name: mod.name, enabled:} }}))
    end

    # Iterate through all mod-version pairs.
    # @yieldparam mod [Factorix::Mod] the mod.
    # @yieldparam enabled [Boolean] the enabled status.
    def each
      return @mods.to_enum unless block_given?

      @mods.each do |mod, enabled|
        yield(mod, enabled)
      end
    end

    # Add the mod to the list.
    # @param mod [Factorix::Mod] the mod to add.
    # @param enabled [Boolean] the enabled status. Default to true.
    # @raise [ArgumentError] if the mod is the base mod and the enabled status is false.
    def add(mod, enabled: true)
      raise ArgumentError, "can't disable the base mod" if mod.base? && enabled == false

      @mods[mod] = enabled
    end

    # Remove the mod from the list.
    # @param mod [Factorix::Mod] the mod to remove.
    # @raise [ArgumentError] if the mod is the base mod.
    def remove(mod)
      raise ArgumentError, "can't remove the base mod" if mod.base?

      @mods.delete(mod)
    end

    # Check if the mod is in the list.
    # @param mod [Factorix::Mod] the mod to check.
    # @return [Boolean] true if the mod is in the list, false otherwise.
    def exist?(mod) = @mods.key?(mod)

    # Check if the mod is enabled.
    # @param mod [Factorix::Mod] the mod to check.
    # @return [Boolean] true if the mod is enabled, false otherwise.
    # @raise [Factorix::ModList::ModNotInListError] if the mod is not in the list.
    def enabled?(mod)
      raise ModNotInListError, mod unless exist?(mod)

      @mods[mod]
    end

    # Enable the mod.
    # @param mod [Factorix::Mod] the mod to enable.
    # @raise [Factorix::ModList::ModNotInListError] if the mod is not in the list.
    def enable(mod)
      raise ModNotInListError, mod unless exist?(mod)

      @mods[mod] = true
    end

    # Disable the mod.
    # @param mod [Factorix::Mod] the mod to disable.
    # @raise [ArgumentError] if the mod is the base mod.
    # @raise [Factorix::ModList::ModNotInListError] if the mod is not in the list.
    def disable(mod)
      raise ArgumentError, "can't disalbe the base mod" if mod.base?
      raise ModNotInListError, mod unless exist?(mod)

      @mods[mod] = false
    end
  end
end
