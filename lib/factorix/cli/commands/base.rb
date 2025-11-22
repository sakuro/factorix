# frozen_string_literal: true

require "dry/cli"
require "tint_me"

module Factorix
  class CLI
    module Commands
      # Base class for all CLI commands
      #
      # This class provides common functionality for all commands:
      # - Common options (--config-path, --log-level, --quiet)
      # - Common helper methods (say, quiet?)
      # - Pre-call setup and error handling (via CommandWrapper prepended module)
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
        # Emoji prefix mapping for common message types
        EMOJI_PREFIXES = {
          success: "\u{2713}",       # CHECK MARK
          info: "\u{2139}",          # INFORMATION SOURCE
          warn: "\u{26A0}\u{FE0E}",  # WARNING SIGN (text presentation)
          error: "\u{2717}",         # BALLOT X
          fatal: "\u{2620}\u{FE0E}"  # SKULL AND CROSSBONES (text presentation)
        }.freeze
        private_constant :EMOJI_PREFIXES

        # Color styles for message prefixes
        STYLES = {
          success: TIntMe[:green],
          info: TIntMe[:cyan],
          warn: TIntMe[:magenta],
          error: TIntMe[:red],
          fatal: TIntMe[:red, :bold]
        }.freeze
        private_constant :STYLES

        # Prepend CommandWrapper to each command class that inherits from Base
        def self.inherited(subclass)
          super
          subclass.prepend CommandWrapper
        end

        # Require that the game is not running when this command executes
        # @return [void]
        def self.require_game_stopped! = prepend RequiresGameStopped

        # Common options available to all commands
        option :config_path, type: :string, aliases: ["-c"], desc: "Path to configuration file"
        option :log_level, type: :string, values: %w[debug info warn error fatal], desc: "Set log level"
        option :quiet, type: :boolean, default: false, aliases: ["-q"], desc: "Suppress non-essential output"

        private def say(message, prefix: "")
          return if quiet?

          resolved_prefix = EMOJI_PREFIXES.fetch(prefix) { prefix.to_s }
          output = resolved_prefix.empty? ? message : "#{resolved_prefix} #{message}"
          output = STYLES[prefix][output] if STYLES.key?(prefix)
          puts output
        end

        private def quiet?
          @quiet == true
        end
      end
    end
  end
end
