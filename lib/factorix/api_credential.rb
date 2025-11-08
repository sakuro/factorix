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
      api_key = ENV.fetch(ENV_API_KEY, nil)
      raise ArgumentError, "#{ENV_API_KEY} environment variable is not set" if api_key.nil?
      raise ArgumentError, "#{ENV_API_KEY} environment variable is empty" if api_key.empty?

      new(api_key:)
    end

    private_class_method :new, :[]
  end
end
