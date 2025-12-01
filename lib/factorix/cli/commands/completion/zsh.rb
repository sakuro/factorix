# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module Completion
        # Generate zsh completion script for factorix
        #
        # This command outputs a zsh completion script that can be evaluated
        # to enable command-line completion for factorix.
        #
        # @example Enable completion in zsh
        #   eval "$(factorix completion zsh)"
        class Zsh < Base
          # Path to zsh completion script
          COMPLETION_SCRIPT_PATH = Pathname(__dir__).join("../../../../../completion/_factorix.zsh").freeze
          private_constant :COMPLETION_SCRIPT_PATH

          desc "Generate zsh completion script"

          example [
            "  # Output zsh completion script",
            '  # Enable with: eval "$(factorix completion zsh)"'
          ]

          # Execute the completion zsh command
          #
          # @return [void]
          def call(**)
            raise Error, "Zsh completion script not found" unless COMPLETION_SCRIPT_PATH.exist?

            puts COMPLETION_SCRIPT_PATH.read
          end
        end
      end
    end
  end
end
