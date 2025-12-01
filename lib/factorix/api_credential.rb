# frozen_string_literal: true

module Factorix
  APICredential = Data.define(:api_key)

  # API credentials for Factorio MOD Portal management
  #
  # @see https://wiki.factorio.com/Mod_upload_API
  # @see https://wiki.factorio.com/Mod_publish_API
  # @see https://wiki.factorio.com/Mod_details_API
  # @see https://wiki.factorio.com/Mod_images_API
  class APICredential
    # @!attribute [r] api_key
    #   @return [String] API key for Factorio MOD Portal

    # Environment variable name for API key
    ENV_API_KEY = "FACTORIO_API_KEY"
    private_constant :ENV_API_KEY

    # Load API credentials from environment variables
    #
    # @return [APICredential] new instance with API key from environment
    # @raise [ArgumentError] if API key is not set in environment
    def self.load
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

    # @return [String] string representation with masked API key
    def inspect = %[#<#{self.class} api_key="*****">]

    alias to_s inspect

    # @param pp [PP] pretty printer
    # @return [void]
    def pretty_print(pp) = pp.text(inspect)
  end
end
