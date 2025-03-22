# frozen_string_literal: true

require "json"
require_relative "runtime"

module Factorix
  # Manages Factorio service credentials
  class Credential
    # Return the service username
    # @return [String] the service username
    def username
      env_value = ENV.fetch("FACTORIO_SERVICE_USERNAME", nil)
      return player_data.fetch("service-username") if env_value.nil? || env_value.empty?

      env_value
    end

    # Return the service token
    # @return [String] the service token
    def token
      env_value = ENV.fetch("FACTORIO_SERVICE_TOKEN", nil)
      return player_data.fetch("service-token") if env_value.nil? || env_value.empty?

      env_value
    end

    private def runtime
      Runtime.runtime
    end

    private def player_data
      @player_data ||= JSON.parse(runtime.player_data_path.read)
    end
  end
end
