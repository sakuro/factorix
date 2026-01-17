# frozen_string_literal: true

module Factorix
  class Runtime
    # Provides user-configurable path overrides for Runtime
    #
    # This module is prepended to Runtime::Base to allow users to override
    # auto-detected paths via configuration. When a configured path is available,
    # it is used instead of platform-specific auto-detection.
    #
    # Configuration is done via Factorix.config:
    #
    # @example Configure paths in config file
    #   Factorix.configure do |config|
    #     config.runtime.executable_path = "/opt/factorio/bin/x64/factorio"
    #     config.runtime.user_dir = "/home/user/.factorio"
    #   end
    #
    # All path resolution decisions are logged at DEBUG level.
    module UserConfigurable
      # Get the Factorio executable path
      #
      # Returns the configured executable path if available, otherwise falls back
      # to platform-specific auto-detection.
      #
      # @return [Pathname] the Factorio executable path
      # @raise [ConfigurationError] if auto-detection is not supported and no configuration is provided
      def executable_path = configurable_path(:executable_path, example_path: "/path/to/factorio") { super }

      # Get the Factorio user directory path
      #
      # Returns the configured user_dir if available, otherwise falls back
      # to platform-specific auto-detection.
      #
      # @return [Pathname] the Factorio user directory
      # @raise [ConfigurationError] if auto-detection is not supported and no configuration is provided
      def user_dir = configurable_path(:user_dir, example_path: "/path/to/factorio/user/dir") { super }

      # Get the Factorio data directory path
      #
      # Returns the configured data_dir if available, otherwise falls back
      # to platform-specific auto-detection.
      #
      # @return [Pathname] the Factorio data directory
      # @raise [ConfigurationError] if auto-detection is not supported and no configuration is provided
      def data_dir = configurable_path(:data_dir, example_path: "/path/to/factorio/data") { super }

      private def configurable_path(name, example_path:)
        if (configured = Factorix.config.runtime.public_send(name))
          Container[:logger].debug("Using configured #{name}", path: configured.to_s)
          configured
        else
          Container[:logger].debug("No configuration for #{name}, using auto-detection")
          yield.tap {|path| Container[:logger].debug("Auto-detected #{name}", path: path.to_s) }
        end
      rescue NotImplementedError => e
        Container[:logger].error("Auto-detection failed and no configuration provided", error: e.message)
        raise ConfigurationError, <<~MESSAGE
          #{name} not configured and auto-detection is not supported for this platform.
          Please configure it in #{Container[:runtime].factorix_config_path}:

            Factorix.configure do |config|
              config.runtime.#{name} = "#{example_path}"
            end
        MESSAGE
      end
    end
  end
end
