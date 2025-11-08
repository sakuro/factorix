# frozen_string_literal: true

module Factorix
  APICredential = Data.define(:api_key)

  # API credentials for Factorio Mod Portal management
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
      new(api_key: ENV.fetch(ENV_API_KEY, nil))
    end

    private_class_method :new, :[]

    # Initialize APICredential with validation
    #
    # @param api_key [String] the API key
    # @raise [ArgumentError] if api_key is nil or empty
    def initialize(api_key:)
      raise ArgumentError, "api_key must not be nil" if api_key.nil?
      raise ArgumentError, "api_key must not be empty" if api_key.empty?

      super
    end
  end
end
