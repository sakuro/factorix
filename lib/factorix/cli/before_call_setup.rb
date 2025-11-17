# frozen_string_literal: true

require "logger"

module Factorix
  class CLI
    # Module that wraps command execution to perform setup before calling the actual command
    #
    # This module is prepended to Base to ensure configuration loading and log level
    # setup happen before every command execution.
    module BeforeCallSetup
      # Performs setup before command execution, then calls the command's implementation
      # @param options [Hash] command options including :config_path and :log_level
      def call(**options)
        @quiet = options[:quiet]

        load_config!(options[:config_path])
        log_level!(options[:log_level]) if options[:log_level]

        # Call the command's implementation
        super
      end

      private def load_config!(path)
        if path
          # Explicitly specified path via --config-path
          Factorix::Application.load_config(path)
        else
          # Load default configuration
          config_path = if ENV["FACTORIX_CONFIG"]
                          Pathname(ENV.fetch("FACTORIX_CONFIG"))
                        else
                          Factorix::Application[:runtime].factorix_config_path
                        end
          Factorix::Application.load_config(config_path) if config_path.exist?
        end
      end

      # Sets the application logger's level
      # @param level [String] log level (debug, info, warn, error, fatal)
      private def log_level!(level)
        logger = Factorix::Application[:logger]
        level_constant = Logger.const_get(level.upcase)

        # Change only the File backend (first backend) level
        # Dispatcher is always set to DEBUG to allow all messages through
        # The stderr backend (second backend) is fixed at WARN level
        file_backend = logger.backends.first
        file_backend.level = level_constant if file_backend.respond_to?(:level=)
      end
    end
  end
end
