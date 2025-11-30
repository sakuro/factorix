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
          # Directory containing completion scripts
          COMPLETION_DIR = Pathname(__dir__).join("../../../../../completion").freeze
          private_constant :COMPLETION_DIR

          # Completion script filename
          COMPLETION_FILE = "_factorix.zsh"
          private_constant :COMPLETION_FILE

          desc "Generate zsh completion script"

          example [
            "  # Output zsh completion script",
            "  # Enable with: eval \"$(factorix completion zsh)\""
          ]

          # Execute the completion zsh command
          #
          # @return [void]
          def call(**)
            puts completion_script
          end

          # Read completion script
          #
          # @return [String] completion script content
          private def completion_script
            file_path = COMPLETION_DIR.join(COMPLETION_FILE)

            raise Error, "Zsh completion script not found" unless file_path.exist?

            file_path.read
          end
        end
      end
    end
  end
end
