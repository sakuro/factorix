# frozen_string_literal: true

require "json"

module Factorix
  # Represents a list of MODs and their enabled status
  #
  # This class manages the mod-list.json file, which contains the list of MODs
  # and their enabled/disabled states.
  class MODList
    include Enumerable

    # Raised when a MOD is not found in the list
    class MODNotInListError < MODNotFoundError; end

    # Load the MOD list from the given file
    #
    # @param path [Pathname] the path to the file to load the MOD list from (default: runtime.mod_list_path)
    # @return [Factorix::MODList] the loaded MOD list
    # @raise [MODSettingsError] if the base MOD is disabled
    def self.load(path=Container[:runtime].mod_list_path)
      raw_data = JSON.parse(path.read, symbolize_names: true)
      mods_hash = raw_data[:mods].to_h {|entry|
        mod = MOD[name: entry[:name]]
        version = entry[:version] ? MODVersion.from_string(entry[:version]) : nil
        state = MODState[enabled: entry[:enabled], version:]

        # Validate that base MOD is not disabled
        if mod.base? && !entry[:enabled]
          raise MODSettingsError, "base MOD cannot be disabled"
        end

        [mod, state]
      }
      new(mods_hash)
    end

    # Initialize the MOD list
    #
    # @param mods [Hash{Factorix::MOD => Factorix::MODState}] the MODs and their state
    # @return [void]
    def initialize(mods={})
      @mods = {}
      mods.each do |mod, state|
        @mods[mod] = state
      end
    end

    # Save the MOD list to the given file
    #
    # @param path [Pathname] the path to the file to save the MOD list to (default: runtime.mod_list_path)
    # @return [void]
    def save(path=Container[:runtime].mod_list_path)
      mods_data = @mods.map {|mod, state|
        data = {name: mod.name, enabled: state.enabled?}
        # Only include version in the output if it exists
        data[:version] = state.version.to_s if state.version
        data
      }
      path.write(JSON.pretty_generate({mods: mods_data}))
    end

    # Iterate through all MOD-state pairs
    #
    # @yieldparam mod [Factorix::MOD] the MOD
    # @yieldparam state [Factorix::MODState] the MOD state
    # @return [Enumerator] if no block is given
    # @return [Factorix::MODList] if a block is given
    def each(&block)
      return @mods.to_enum unless block

      @mods.each(&block)
      self
    end

    # Iterate through all MODs
    #
    # @yieldparam mod [Factorix::MOD] the MOD
    # @return [Enumerator] if no block is given
    # @return [Factorix::MODList] if a block is given
    def each_mod(&block)
      return @mods.keys.to_enum unless block

      @mods.each_key(&block)
      self
    end

    # Alias for each_mod
    #
    # @yieldparam mod [Factorix::MOD] the MOD
    # @return [Enumerator] if no block is given
    # @return [Factorix::MODList] if a block is given
    alias each_key each_mod

    # Add the MOD to the list
    #
    # @param mod [Factorix::MOD] the MOD to add
    # @param enabled [Boolean] the enabled status. Default to true
    # @param version [Factorix::MODVersion, nil] the version of the MOD. Default to nil
    # @return [void]
    # @raise [MODSettingsError] if the MOD is the base MOD and the enabled status is false
    def add(mod, enabled: true, version: nil)
      raise MODSettingsError, "can't disable the base MOD" if mod.base? && enabled == false

      @mods[mod] = MODState[enabled:, version:]
    end

    # Remove the MOD from the list
    #
    # @param mod [Factorix::MOD] the MOD to remove
    # @return [void]
    # @raise [MODSettingsError] if the MOD is the base MOD or an expansion MOD
    def remove(mod)
      raise MODSettingsError, "can't remove the base MOD" if mod.base?
      raise MODSettingsError, "can't remove expansion MOD: #{mod}" if mod.expansion?

      @mods.delete(mod)
    end

    # Check if the MOD is in the list
    #
    # @param mod [Factorix::MOD] the MOD to check
    # @return [Boolean] true if the MOD is in the list, false otherwise
    def exist?(mod) = @mods.key?(mod)

    # Check if the MOD is enabled
    #
    # @param mod [Factorix::MOD] the MOD to check
    # @return [Boolean] true if the MOD is enabled, false otherwise
    # @raise [Factorix::MODList::MODNotInListError] if the MOD is not in the list
    def enabled?(mod)
      raise MODNotInListError, "MOD not in the list: #{mod}" unless exist?(mod)

      @mods[mod].enabled?
    end

    # Get the version of the MOD
    #
    # @param mod [Factorix::MOD] the MOD to check
    # @return [Factorix::MODVersion, nil] the version of the MOD, or nil if not specified
    # @raise [Factorix::MODList::MODNotInListError] if the MOD is not in the list
    def version(mod)
      raise MODNotInListError, "MOD not in the list: #{mod}" unless exist?(mod)

      @mods[mod].version
    end

    # Enable the MOD
    #
    # @param mod [Factorix::MOD] the MOD to enable
    # @return [void]
    # @raise [Factorix::MODList::MODNotInListError] if the MOD is not in the list
    def enable(mod)
      raise MODNotInListError, "MOD not in the list: #{mod}" unless exist?(mod)

      current_state = @mods[mod]
      @mods[mod] = MODState[enabled: true, version: current_state.version]
    end

    # Disable the MOD
    #
    # @param mod [Factorix::MOD] the MOD to disable
    # @return [void]
    # @raise [MODSettingsError] if the MOD is the base MOD
    # @raise [Factorix::MODList::MODNotInListError] if the MOD is not in the list
    def disable(mod)
      raise MODSettingsError, "can't disable the base MOD" if mod.base?
      raise MODNotInListError, "MOD not in the list: #{mod}" unless exist?(mod)

      current_state = @mods[mod]
      @mods[mod] = MODState[enabled: false, version: current_state.version]
    end
  end
end
