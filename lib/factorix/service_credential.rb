# frozen_string_literal: true

require "json"

module Factorix
  ServiceCredential = Data.define(:username, :token)

  # Service credentials for Factorio MOD downloads
  #
  # @!attribute [r] username
  #   @return [String] Factorio service username
  # @!attribute [r] token
  #   @return [String] Factorio service token
  #
  # @see https://wiki.factorio.com/Mod_portal_API
  class ServiceCredential
    # Environment variable name for username
    ENV_USERNAME = "FACTORIO_USERNAME"
    private_constant :ENV_USERNAME

    # Environment variable name for token
    ENV_TOKEN = "FACTORIO_TOKEN"
    private_constant :ENV_TOKEN

    # Create a new ServiceCredential instance from environment variables
    #
    # @return [ServiceCredential] new instance with credentials from environment
    # @raise [ArgumentError] if username or token is not set in environment
    def self.from_env
      username = ENV.fetch(ENV_USERNAME, nil)
      token = ENV.fetch(ENV_TOKEN, nil)

      raise ArgumentError, "#{ENV_USERNAME} environment variable is not set" if username.nil?
      raise ArgumentError, "#{ENV_USERNAME} environment variable is empty" if username.empty?
      raise ArgumentError, "#{ENV_TOKEN} environment variable is not set" if token.nil?
      raise ArgumentError, "#{ENV_TOKEN} environment variable is empty" if token.empty?

      new(username:, token:)
    end

    # Create a new ServiceCredential instance from player-data.json
    #
    # @param runtime [Factorix::Runtime::Base] runtime instance
    # @return [ServiceCredential] new instance with credentials from player-data.json
    # @raise [Errno::ENOENT] if player-data.json does not exist
    # @raise [ArgumentError] if username or token is missing in player-data.json
    def self.from_player_data(runtime:)
      player_data_path = runtime.player_data_path
      data = JSON.parse(player_data_path.read)

      username = data["service-username"]
      token = data["service-token"]

      raise ArgumentError, "service-username is missing in player-data.json" if username.nil?
      raise ArgumentError, "service-username is empty in player-data.json" if username.empty?
      raise ArgumentError, "service-token is missing in player-data.json" if token.nil?
      raise ArgumentError, "service-token is empty in player-data.json" if token.empty?

      new(username:, token:)
    end

    private_class_method :new, :[]
  end
end
