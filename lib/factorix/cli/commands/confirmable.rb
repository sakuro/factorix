# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      # Mixin for commands that require user confirmation
      #
      # This module provides:
      # - --yes option to skip confirmation prompts
      # - confirm? method to ask for user confirmation
      #
      # Prepend this module to commands that need confirmation
      # (e.g., enable, disable, install, uninstall)
      module Confirmable
        # Hook called when this module is prepended to a class
        # @param base [Class] the class prepending this module
        def self.prepended(base)
          base.class_eval do
            option :yes, type: :flag, default: false, aliases: ["-y"], desc: "Skip confirmation prompts"
          end
        end

        # Store the --yes flag for use in confirm?
        # @param options [Hash] command options
        def call(**options)
          @yes = options[:yes]
          super
        end

        # Ask for user confirmation
        #
        # @param message [String] confirmation message to display
        # @return [Boolean] true if user confirms, false otherwise
        # @raise [InvalidOperationError] if in quiet mode without --yes flag
        private def confirm?(message="Do you want to continue?")
          # --yes flag skips confirmation
          return true if @yes

          # Cannot prompt in quiet mode
          if quiet?
            raise InvalidOperationError, "Cannot prompt for confirmation in quiet mode. Use --yes to proceed automatically."
          end

          print "#{message} [y/N] "
          response = $stdin.gets&.strip&.downcase

          # Only explicit y or yes means yes (default is no for safety)
          response == "y" || response == "yes"
        end
      end
    end
  end
end
