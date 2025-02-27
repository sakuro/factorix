# frozen_string_literal: true

module Factorix
  # Represent the state of a MOD in a mod list
  ModState = Data.define(:enabled, :version) {
    # Initialize a new ModState
    # @param enabled [Boolean] whether the mod is enabled
    # @param version [String, nil] the version of the mod (optional)
    def initialize(enabled:, version: nil)
      super
    end

    # !attribute [r] enabled
    #  @return [Boolean] whether the mod is enabled

    # !attribute [r] version
    #  @return [String, nil] the version of the mod, or nil if the version is not specified
  }
end
