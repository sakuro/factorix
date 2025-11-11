# frozen_string_literal: true

module Factorix
  MODState = Data.define(:enabled, :version)

  # Represents the state of a MOD in a MOD list
  #
  # This class encapsulates the enabled/disabled state and version information
  # for a MOD as it appears in the mod-list.json file.
  class MODState
    # Initialize a new MODState
    #
    # @param enabled [Boolean] whether the MOD is enabled
    # @param version [Factorix::Types::MODVersion, nil] the version of the MOD (optional)
    # @return [void]
    #
    # @example Creating a MODState
    #   state = Factorix::MODState[enabled: true]
    #   version = Factorix::Types::MODVersion.from_string("1.2.3")
    #   state = Factorix::MODState[enabled: false, version: version]
    def initialize(enabled:, version: nil)
      super
    end

    # @!attribute [r] enabled
    #   @return [Boolean] whether the MOD is enabled

    # @!attribute [r] version
    #   @return [Factorix::Types::MODVersion, nil] the version of the MOD, or nil if the version is not specified

    # Check if the MOD is enabled
    #
    # @return [Boolean] true if the MOD is enabled, false otherwise
    def enabled?
      enabled
    end
  end
end
