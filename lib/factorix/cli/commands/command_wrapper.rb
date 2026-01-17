# frozen_string_literal: true

require "logger"

module Factorix
  class CLI
    module Commands
      # Module that wraps command execution to perform setup and error handling
      #
      # This module is prepended to Base to ensure configuration loading, log level
      # setup, and consistent error handling happen for every command execution.
      module CommandWrapper
        # Performs setup before command execution, then calls the command's implementation
        # Catches exceptions and displays user-friendly error messages
        #
        # @param options [Hash] command options including :config_path and :log_level
        def call(**options)
          @quiet = options[:quiet]

          load_config!(options[:config_path])
          log_level!(options[:log_level]) if options[:log_level]

          super
        rescue Error => e
          # Expected errors (validation failures, missing dependencies, etc.)
          log = Container[:logger]
          log.warn(e.message)
          log.debug(e)
          say "Error: #{e.message}", prefix: :error unless @quiet
          raise # Re-raise for exe/factorix to handle exit code
        rescue => e
          # Unexpected errors (bugs, system failures, etc.)
          log = Container[:logger]
          log.error(e)
          say "Unexpected error: #{e.message}", prefix: :error unless @quiet
          raise # Re-raise for exe/factorix to handle exit code
        end

        private def load_config!(explicit_path)
          path = resolve_config_path(explicit_path)
          return unless path

          Factorix.load_config(path)
        end

        # Resolves which config path to use
        # @param explicit_path [String, nil] path specified via --config-path
        # @return [Pathname, nil] path to load, or nil if none should be loaded
        private def resolve_config_path(explicit_path)
          return Pathname(explicit_path) if explicit_path
          return Pathname(ENV.fetch("FACTORIX_CONFIG")) if ENV["FACTORIX_CONFIG"]

          default_path = Container[:runtime].factorix_config_path
          default_path.exist? ? default_path : nil
        end

        # Sets the application logger's level
        # @param level [String] log level (debug, info, warn, error, fatal)
        private def log_level!(level)
          logger = Container[:logger]
          level_constant = Logger.const_get(level.upcase)

          # Change only the File backend (first backend) level
          # Dispatcher is always set to DEBUG to allow all messages through
          file_backend = logger.backends.first
          file_backend.level = level_constant if file_backend.respond_to?(:level=)
        end
      end
    end
  end
end
