# frozen_string_literal: true

module Factorix
  # Manages temporary MOD configurations.
  class ModContext
    # Initialize a new MOD context with the given MOD list.
    #
    # @param mod_list [Factorix::ModList] the MOD list.
    def initialize(mod_list)
      @mod_list = mod_list
      @original_states = {}
    end

    # Execute a block with only specified MODs enabled.
    # Temporarily enables only the specified MODs and the base MOD, disabling all others.
    # The original MOD states are restored after the block execution, even if an error occurs.
    #
    # @param mod_names [Array<String>] the names of the MODs to enable
    def with_only_enabled(*mod_names, &)
      save_original_states
      enable_only_specified(*mod_names)

      yield
    ensure
      restore_original_states
    end

    private attr_reader :mod_list
    private attr_reader :original_states

    # Save the current enabled state of all MODs.
    #
    # @return [void]
    private def save_original_states
      @original_states = mod_list.each_mod.with_object({}) do |mod, states|
        states[mod] = mod_list.enabled?(mod)
      end
    end

    # Enable only the specified MODs and the base MOD, disable all others.
    #
    # @param mod_names [Array<String>] the names of the MODs to enable.
    # @return [void]
    private def enable_only_specified(*mod_names)
      mod_list.each_mod do |mod|
        should_enable = mod.base? || mod_names.include?(mod.name)
        mod_list.public_send(should_enable ? :enable : :disable, mod)
      end
      mod_list.save
    end

    # Restore the original enabled state of all MODs.
    #
    # @return [void]
    private def restore_original_states
      original_states.each do |mod, was_enabled|
        mod_list.public_send(was_enabled ? :enable : :disable, mod)
      end
      mod_list.save
    end
  end
end
