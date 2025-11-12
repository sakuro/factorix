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

      begin
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
      rescue => e
        logger.error("Failed to load credentials from player-data.json", error_class: e.class.name, error_message: e.message)
        raise
      end
    end

    private_class_method :new, :[]
  end
end
