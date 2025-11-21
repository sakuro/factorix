# frozen_string_literal: true

module Factorix
  class Runtime
    # Provides user-configurable path overrides for Runtime
    #
    # This module is prepended to Runtime::Base to allow users to override
    # auto-detected paths via configuration. When a configured path is available,
    # it is used instead of platform-specific auto-detection.
    #
    # Configuration is done via Application.config:
    #
    # @example Configure paths in config file
    #   Factorix::Application.configure do |config|
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
      def executable_path
        if (configured = Application.config.runtime.executable_path)
          Application[:logger].debug("Using configured executable_path", path: configured.to_s)
          configured
        else
          Application[:logger].debug("No configuration for executable_path, using auto-detection")
          super.tap {|path| Application[:logger].debug("Auto-detected executable_path", path: path.to_s) }
        end
      rescue NotImplementedError => e
        Application[:logger].error("Auto-detection failed and no configuration provided", error: e.message)
        raise ConfigurationError, <<~MESSAGE
          executable_path not configured and auto-detection is not supported for this platform.
          Please configure it in #{Application[:runtime].factorix_config_path}:

            Factorix::Application.configure do |config|
              config.runtime.executable_path = "/path/to/factorio"
            end
        MESSAGE
      end

      # Get the Factorio user directory path
      #
      # Returns the configured user_dir if available, otherwise falls back
      # to platform-specific auto-detection.
      #
      # @return [Pathname] the Factorio user directory
      # @raise [ConfigurationError] if auto-detection is not supported and no configuration is provided
      def user_dir
        if (configured = Application.config.runtime.user_dir)
          Application[:logger].debug("Using configured user_dir", path: configured.to_s)
          configured
        else
          Application[:logger].debug("No configuration for user_dir, using auto-detection")
          super.tap {|path| Application[:logger].debug("Auto-detected user_dir", path: path.to_s) }
        end
      rescue NotImplementedError => e
        Application[:logger].error("Auto-detection failed and no configuration provided", error: e.message)
        raise ConfigurationError, <<~MESSAGE
          user_dir not configured and auto-detection is not supported for this platform.
          Please configure it in #{Application[:runtime].factorix_config_path}:

            Factorix::Application.configure do |config|
              config.runtime.user_dir = "/path/to/factorio/user/dir"
            end
        MESSAGE
      end

      # Get the Factorio data directory path
      #
      # Returns the configured data_dir if available, otherwise falls back
      # to platform-specific auto-detection.
      #
      # @return [Pathname] the Factorio data directory
      # @raise [ConfigurationError] if auto-detection is not supported and no configuration is provided
      def data_dir
        if (configured = Application.config.runtime.data_dir)
          Application[:logger].debug("Using configured data_dir", path: configured.to_s)
          configured
        else
          Application[:logger].debug("No configuration for data_dir, using auto-detection")
          super.tap {|path| Application[:logger].debug("Auto-detected data_dir", path: path.to_s) }
        end
      rescue NotImplementedError => e
        Application[:logger].error("Auto-detection failed and no configuration provided", error: e.message)
        raise ConfigurationError, <<~MESSAGE
          data_dir not configured and auto-detection is not supported for this platform.
          Please configure it in #{Application[:runtime].factorix_config_path}:

            Factorix::Application.configure do |config|
              config.runtime.data_dir = "/path/to/factorio/data"
            end
        MESSAGE
      end
    end
  end
end
