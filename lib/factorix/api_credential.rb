# frozen_string_literal: true

module Factorix
  APICredential = Data.define(:api_key)

  # API credentials for Factorio MOD Portal management
  #
  # @!attribute [r] api_key
  #   @return [String] API key for Factorio MOD Portal
  #
  # @see https://wiki.factorio.com/Mod_upload_API
  class APICredential
    # Environment variable name for API key
    ENV_API_KEY = "FACTORIO_API_KEY"
    private_constant :ENV_API_KEY

    # Create a new APICredential instance from environment variables
    #
    # @return [APICredential] new instance with API key from environment
    # @raise [ArgumentError] if API key is not set in environment
    def self.from_env
      logger = Application["logger"]
      logger.debug "Loading API credentials from environment"

      api_key = ENV.fetch(ENV_API_KEY, nil)
      if api_key.nil?
        logger.error("Failed to load API credentials", reason: "#{ENV_API_KEY} not set")
        raise ArgumentError, "#{ENV_API_KEY} environment variable is not set"
      end

      if api_key.empty?
        logger.error("Failed to load API credentials", reason: "#{ENV_API_KEY} is empty")
        raise ArgumentError, "#{ENV_API_KEY} environment variable is empty"
      end

      logger.info("API credentials loaded successfully")
      new(api_key:)
    end

    private_class_method :new, :[]
  end
end
