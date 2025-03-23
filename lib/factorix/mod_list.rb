# frozen_string_literal: true

require "json"
require_relative "errors"
require_relative "mod"
require_relative "mod_state"
require_relative "runtime"

module Factorix
  # Represent a list of MODs and their enabled status.
  class ModList
    include Enumerable

    # Raised when a MOD is not found.
    class ModNotInListError < Factorix::ModNotFoundError; end

    # Load the MOD list from the given file.
    #
    # @param from [Pathname] the path to the file to load the MOD list from.
    # @return [Factorix::ModList] the loaded MOD list.
    def self.load(from: Factorix::Runtime.runtime.mod_list_path)
      raw_data = JSON.parse(from.read, symbolize_names: true)
      new(raw_data[:mods].to_h {|e|
        [Factorix::Mod[name: e[:name]], Factorix::ModState[enabled: e[:enabled], version: e[:version]]]
      })
    end

    # Initialize the MOD list.
    #
    # @param mods [Hash{Factorix::Mod => ModState}] the MODs and their state.
    # @return [void]
    def initialize(mods={})
      @mods = {}
      mods.each do |mod, state|
        @mods[mod] = state
      end
    end

    # Save the MOD list to the given file.
    #
    # @param to [Pathname] the path to the file to save the MOD list to.
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

    # Iterate through all MOD-state pairs.
    #
    # @yieldparam mod [Factorix::Mod] the MOD.
    # @yieldparam state [Factorix::ModState] the MOD state.
    # @return [Enumerator] if no block is given.
    # @return [Factorix::ModList] if a block is given.
    def each
      return @mods.to_enum unless block_given?

      @mods.each do |mod, state|
        yield(mod, state)
      end
    end

    # Iterate through all MODs.
    #
    # @yieldparam mod [Factorix::Mod] the MOD.
    # @return [Enumerator] if no block is given.
    # @return [Factorix::ModList] if a block is given.
    def each_mod
      return @mods.keys.to_enum unless block_given?

      @mods.each_key do |mod|
        yield(mod)
      end
    end

    # Alias for each_mod
    #
    # @yieldparam mod [Factorix::Mod] the MOD.
    # @return [Enumerator] if no block is given.
    # @return [Factorix::ModList] if a block is given.
    alias each_key each_mod

    # Add the MOD to the list.
    #
    # @param mod [Factorix::Mod] the MOD to add.
    # @param enabled [Boolean] the enabled status. Default to true.
    # @param version [String, nil] the version of the MOD. Default to nil.
    # @return [void]
    # @raise [ArgumentError] if the MOD is the base MOD and the enabled status is false.
    def add(mod, enabled: true, version: nil)
      raise ArgumentError, "can't disable the base MOD" if mod.base? && enabled == false

      @mods[mod] = ModState[enabled:, version:]
    end

    # Remove the MOD from the list.
    #
    # @param mod [Factorix::Mod] the MOD to remove.
    # @return [void]
    # @raise [ArgumentError] if the MOD is the base MOD.
    def remove(mod)
      raise ArgumentError, "can't remove the base MOD" if mod.base?

      @mods.delete(mod)
    end

    # Check if the MOD is in the list.
    #
    # @param mod [Factorix::Mod] the MOD to check.
    # @return [Boolean] true if the MOD is in the list, false otherwise.
    def exist?(mod) = @mods.key?(mod)

    # Check if the MOD is enabled.
    #
    # @param mod [Factorix::Mod] the MOD to check.
    # @return [Boolean] true if the MOD is enabled, false otherwise.
    # @raise [Factorix::ModList::ModNotInListError] if the MOD is not in the list.
    def enabled?(mod)
      raise ModNotInListError, "MOD not in the list: #{mod}" unless exist?(mod)

      @mods[mod].enabled
    end

    # Get the version of the MOD.
    #
    # @param mod [Factorix::Mod] the MOD to check.
    # @return [String, nil] the version of the MOD, or nil if not specified.
    # @raise [Factorix::ModList::ModNotInListError] if the MOD is not in the list.
    def version(mod)
      raise ModNotInListError, "MOD not in the list: #{mod}" unless exist?(mod)

      @mods[mod].version
    end

    # Enable the MOD.
    #
    # @param mod [Factorix::Mod] the MOD to enable.
    # @return [void]
    # @raise [Factorix::ModList::ModNotInListError] if the MOD is not in the list.
    def enable(mod)
      raise ModNotInListError, "MOD not in the list: #{mod}" unless exist?(mod)

      # Create a new ModState with enabled=true and the same version
      current_state = @mods[mod]
      @mods[mod] = ModState[enabled: true, version: current_state.version]
    end

    # Disable the MOD.
    #
    # @param mod [Factorix::Mod] the MOD to disable.
    # @return [void]
    # @raise [ArgumentError] if the MOD is the base MOD.
    # @raise [Factorix::ModList::ModNotInListError] if the MOD is not in the list.
    def disable(mod)
      raise ArgumentError, "can't disable the base MOD" if mod.base?
      raise ModNotInListError, "MOD not in the list: #{mod}" unless exist?(mod)

      # Create a new ModState with enabled=false and the same version
      current_state = @mods[mod]
      @mods[mod] = ModState[enabled: false, version: current_state.version]
    end
  end
end
