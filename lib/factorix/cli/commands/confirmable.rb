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
      # Include this module in commands that need confirmation
      # (e.g., enable, disable, install, uninstall)
      module Confirmable
        # Hook called when this module is included in a class
        # @param base [Class] the class including this module
        def self.included(base)
          base.class_eval do
            option :yes,
              type: :boolean,
              default: false,
              aliases: ["-y"],
              desc: "Skip confirmation prompts"
          end
        end

        private def confirm?(message="Do you want to continue?")
          # --yes flag skips confirmation
          return true if @yes

          # Cannot prompt in quiet mode
          if quiet?
            raise Factorix::Error, "Cannot prompt for confirmation in quiet mode. Use --yes to proceed automatically."
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
