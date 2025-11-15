# frozen_string_literal: true

module Factorix
  class CLI
    # Common options shared across all CLI commands
    module CommonOptions
      # Hook called when this module is prepended to a class
      # @param base [Class] the class this module is being prepended to
      def self.prepended(base)
        base.class_eval do
          option :log_level,
            type: :string,
            values: %w[debug info warn error fatal],
            desc: "Set log level"
        end
      end

      # Wraps the call method to set log level before executing command
      # @param options [Hash] command options including :log_level
      def call(**options)
        log_level!(options[:log_level]) if options[:log_level]
        super
      end

      private

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
