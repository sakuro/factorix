# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module Completion
        # Generate fish completion script for factorix
        #
        # This command outputs a fish completion script that can be sourced
        # to enable command-line completion for factorix.
        #
        # @example Enable completion in fish
        #   factorix completion fish | source
        class Fish < Base
          # Path to fish completion script
          COMPLETION_SCRIPT_PATH = Pathname(__dir__).join("../../../../../completion/_factorix.fish").freeze
          private_constant :COMPLETION_SCRIPT_PATH

          desc "Generate fish completion script"

          example [
            "  # Output fish completion script",
            "  # Enable with: factorix completion fish | source"
          ]

          # Execute the completion fish command
          #
          # @return [void]
          def call(**)
            raise Error, "Fish completion script not found" unless COMPLETION_SCRIPT_PATH.exist?

            puts COMPLETION_SCRIPT_PATH.read
          end
        end
      end
    end
  end
end
