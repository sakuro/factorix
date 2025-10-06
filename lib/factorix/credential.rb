# frozen_string_literal: true

require "json"

module Factorix
  # Manages Factorio service credentials
  class Credential
    # Get the Factorio service username from environment variable or player data.
    # First checks FACTORIO_SERVICE_USERNAME environment variable,
    # then falls back to the service-username in player-data.json if not set
    #
    # @return [String] the service username
    def username
      env_value = ENV.fetch("FACTORIO_SERVICE_USERNAME", nil)
      return player_data.fetch("service-username") if env_value.nil? || env_value.empty?

      env_value
    end

    # Get the Factorio service token from environment variable or player data.
    # First checks FACTORIO_SERVICE_TOKEN environment variable,
    # then falls back to the service-token in player-data.json if not set
    #
    # @return [String] the service token
    def token
      env_value = ENV.fetch("FACTORIO_SERVICE_TOKEN", nil)
      return player_data.fetch("service-token") if env_value.nil? || env_value.empty?

      env_value
    end

    # Get the runtime environment instance
    #
    # @return [Runtime] the runtime environment
    private def runtime
      Runtime.runtime
    end

    # Get the player data from player-data.json
    #
    # @return [Hash] the parsed player data
    private def player_data
      @player_data ||= JSON.parse(runtime.player_data_path.read)
    end
  end
end
