# frozen_string_literal: true

require "json"

module Factorix
  ServiceCredential = Data.define(:username, :token)

  # Service credentials for Factorio MOD downloads
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
      new(
        username: ENV.fetch(ENV_USERNAME, nil),
        token: ENV.fetch(ENV_TOKEN, nil)
      )
    end

    # Create a new ServiceCredential instance from player-data.json
    #
    # @return [ServiceCredential] new instance with credentials from player-data.json
    # @raise [Errno::ENOENT] if player-data.json does not exist
    # @raise [ArgumentError] if username or token is missing in player-data.json
    def self.from_player_data
      runtime = Factorix::Runtime.detect
      player_data_path = runtime.player_data_path
      data = JSON.parse(player_data_path.read)

      new(
        username: data["service-username"],
        token: data["service-token"]
      )
    end

    private_class_method :new, :[]

    # Initialize ServiceCredential with validation
    #
    # @param username [String] the username
    # @param token [String] the token
    # @raise [ArgumentError] if username or token is nil or empty
    def initialize(username:, token:)
      raise ArgumentError, "username must not be nil" if username.nil?
      raise ArgumentError, "username must not be empty" if username.empty?
      raise ArgumentError, "token must not be nil" if token.nil?
      raise ArgumentError, "token must not be empty" if token.empty?

      super
    end
  end
end
