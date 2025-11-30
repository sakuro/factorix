# frozen_string_literal: true

require "json"

module Factorix
  ServiceCredential = Data.define(:username, :token)

  # Service credentials for Factorio MOD downloads
  #
  # @see https://wiki.factorio.com/Mod_portal_API
  class ServiceCredential
    # @!attribute [r] username
    #   @return [String] Factorio service username
    # @!attribute [r] token
    #   @return [String] Factorio service token

    # Environment variable name for username
    ENV_USERNAME = "FACTORIO_USERNAME"
    private_constant :ENV_USERNAME

    # Environment variable name for token
    ENV_TOKEN = "FACTORIO_TOKEN"
    private_constant :ENV_TOKEN

    # Load service credentials with automatic source detection
    #
    # Tries environment variables first, falls back to player-data.json.
    # Raises an error if only one environment variable is set (partial configuration).
    #
    # @return [ServiceCredential] new instance with credentials
    # @raise [ArgumentError] if only one of FACTORIO_USERNAME/FACTORIO_TOKEN is set
    # @raise [ArgumentError] if credentials are invalid or missing
    def self.load
      username_env = ENV.fetch(ENV_USERNAME, nil)
      token_env = ENV.fetch(ENV_TOKEN, nil)

      if username_env && token_env
        from_env
      elsif username_env || token_env
        raise ArgumentError, "Both #{ENV_USERNAME} and #{ENV_TOKEN} must be set (or neither)"
      else
        runtime = Application[:runtime]
        from_player_data(runtime:)
      end
    end

    # Create a new ServiceCredential instance from environment variables
    #
    # @return [ServiceCredential] new instance with credentials from environment
    # @raise [ArgumentError] if username or token is not set or empty
    def self.from_env
      logger = Application["logger"]
      logger.debug "Loading service credentials from environment"

      username = ENV.fetch(ENV_USERNAME, nil)
      token = ENV.fetch(ENV_TOKEN, nil)

      if username.nil?
        logger.error("Failed to load service credentials", reason: "#{ENV_USERNAME} not set")
        raise ArgumentError, "#{ENV_USERNAME} environment variable is not set"
      end
      if username.empty?
        logger.error("Failed to load service credentials", reason: "#{ENV_USERNAME} is empty")
        raise ArgumentError, "#{ENV_USERNAME} environment variable is empty"
      end
      if token.nil?
        logger.error("Failed to load service credentials", reason: "#{ENV_TOKEN} not set")
        raise ArgumentError, "#{ENV_TOKEN} environment variable is not set"
      end
      if token.empty?
        logger.error("Failed to load service credentials", reason: "#{ENV_TOKEN} is empty")
        raise ArgumentError, "#{ENV_TOKEN} environment variable is empty"
      end

      logger.info("Service credentials loaded successfully")
      new(username:, token:)
    end

    # Create a new ServiceCredential instance from player-data.json
    #
    # @param runtime [Factorix::Runtime::Base] runtime instance
    # @return [ServiceCredential] new instance with credentials from player-data.json
    # @raise [Errno::ENOENT] if player-data.json does not exist
    # @raise [ArgumentError] if username or token is missing in player-data.json
    def self.from_player_data(runtime:)
      logger = Application["logger"]
      logger.debug "Loading service credentials from player-data.json"

      player_data_path = runtime.player_data_path
      data = JSON.parse(player_data_path.read)

      username = data["service-username"]
      token = data["service-token"]

      if username.nil?
        logger.error("Failed to load credentials from player-data.json", reason: "service-username missing")
        raise ArgumentError, "service-username is missing in player-data.json"
      end
      if username.empty?
        logger.error("Failed to load credentials from player-data.json", reason: "service-username empty")
        raise ArgumentError, "service-username is empty in player-data.json"
      end
      if token.nil?
        logger.error("Failed to load credentials from player-data.json", reason: "service-token missing")
        raise ArgumentError, "service-token is missing in player-data.json"
      end
      if token.empty?
        logger.error("Failed to load credentials from player-data.json", reason: "service-token empty")
        raise ArgumentError, "service-token is empty in player-data.json"
      end

      logger.info("Service credentials loaded from player-data.json")
      new(username:, token:)
    end

    private_class_method :new, :[], :from_env, :from_player_data
  end
end
