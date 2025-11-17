# frozen_string_literal: true

require "dry/cli"

module Factorix
  class CLI
    module Commands
      # Base class for all CLI commands
      #
      # This class provides common functionality for all commands:
      # - Common options (--config-path, --log-level, --quiet)
      # - Common helper methods (say, quiet?)
      # - Pre-call setup (via BeforeCallSetup prepended module)
      #
      # All command classes should inherit from this base class instead of
      # directly from Dry::CLI::Command.
      #
      # @example Define a command
      #   class MyCommand < Base
      #     desc "My command description"
      #
      #     def call(**)
      #       say "Hello, world!"
      #     end
      #   end
      class Base < Dry::CLI::Command
        # Prepend BeforeCallSetup to each command class that inherits from Base
        def self.inherited(subclass)
          super
          subclass.prepend BeforeCallSetup
        end

        # Common options available to all commands
        option :config_path, type: :string, aliases: ["-c"], desc: "Path to configuration file"
        option :log_level, type: :string, values: %w[debug info warn error fatal], desc: "Set log level"
        option :quiet, type: :boolean, default: false, aliases: ["-q"], desc: "Suppress non-essential output"

        private def say(message)
          return if quiet?

          puts message
        end

        private def quiet?
          @quiet == true
        end
      end
    end
  end
end
