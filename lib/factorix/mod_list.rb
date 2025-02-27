# frozen_string_literal: true

require "json"
require_relative "errors"
require_relative "mod_state"

module Factorix
  # Represent a list of MODs and their enabled status.
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
    # @return [Factorix::ModList] the loaded mod list.
    def self.load(from: Factorix::Runtime.runtime.mod_list_path)
      raw_data = JSON.parse(from.read, symbolize_names: true)
      new(raw_data[:mods].to_h {|e| [Mod[name: e[:name]], ModState[enabled: e[:enabled], version: e[:version]]] })
    end

    # Initialize the mod list.
    # @param mods [Hash{Factorix::Mod => ModState}] the mods and their state.
    # @return [void]
    def initialize(mods={})
      @mods = {}
      mods.each do |mod, state|
        @mods[mod] = state
      end
    end

    # Save the mod list to the given file.
    # @param to [Pathname] the path to the file to save the mod list to.
    # @return [void]
    def save(to: Factorix::Runtime.runtime.mod_list_path)
      mods_data = @mods.map {|mod, state|
        data = {name: mod.name, enabled: state.enabled}
        # Only include version in the output if it exists
        data[:version] = state.version if state.version
        data
      }
      to.write(JSON.pretty_generate({mods: mods_data}))
    end

    # Iterate through all mod-state pairs.
    # @yieldparam mod [Factorix::Mod] the mod.
    # @yieldparam state [Factorix::ModState] the mod state.
    # @return [Enumerator] if no block is given.
    # @return [Factorix::ModList] if a block is given.
    def each
      return @mods.to_enum unless block_given?

      @mods.each do |mod, state|
        yield(mod, state)
      end
    end

    # Iterate through all mods.
    # @yieldparam mod [Factorix::Mod] the mod.
    # @return [Enumerator] if no block is given.
    # @return [Factorix::ModList] if a block is given.
    def each_key
      return @mods.keys.to_enum unless block_given?

      @mods.each_key do |mod|
        yield(mod)
      end
    end

    # Alias for each_key
    # @yieldparam mod [Factorix::Mod] the mod.
    # @return [Enumerator] if no block is given.
    # @return [Factorix::ModList] if a block is given.
    alias each_mod each_key

    # Add the mod to the list.
    # @param mod [Factorix::Mod] the mod to add.
    # @param enabled [Boolean] the enabled status. Default to true.
    # @param version [String, nil] the version of the mod. Default to nil.
    # @return [void]
    # @raise [ArgumentError] if the mod is the base mod and the enabled status is false.
    def add(mod, enabled: true, version: nil)
      raise ArgumentError, "can't disable the base mod" if mod.base? && enabled == false

      @mods[mod] = ModState[enabled:, version:]
    end

    # Remove the mod from the list.
    # @param mod [Factorix::Mod] the mod to remove.
    # @return [void]
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

      @mods[mod].enabled
    end

    # Get the version of the mod.
    # @param mod [Factorix::Mod] the mod to check.
    # @return [String, nil] the version of the mod, or nil if not specified.
    # @raise [Factorix::ModList::ModNotInListError] if the mod is not in the list.
    def version(mod)
      raise ModNotInListError, mod unless exist?(mod)

      @mods[mod].version
    end

    # Enable the mod.
    # @param mod [Factorix::Mod] the mod to enable.
    # @return [void]
    # @raise [Factorix::ModList::ModNotInListError] if the mod is not in the list.
    def enable(mod)
      raise ModNotInListError, mod unless exist?(mod)

      # Create a new ModState with enabled=true and the same version
      current_state = @mods[mod]
      @mods[mod] = ModState[enabled: true, version: current_state.version]
    end

    # Disable the mod.
    # @param mod [Factorix::Mod] the mod to disable.
    # @return [void]
    # @raise [ArgumentError] if the mod is the base mod.
    # @raise [Factorix::ModList::ModNotInListError] if the mod is not in the list.
    def disable(mod)
      raise ArgumentError, "can't disable the base mod" if mod.base?
      raise ModNotInListError, mod unless exist?(mod)

      # Create a new ModState with enabled=false and the same version
      current_state = @mods[mod]
      @mods[mod] = ModState[enabled: false, version: current_state.version]
    end
  end
end
