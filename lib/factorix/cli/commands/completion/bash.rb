# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module Completion
        # Generate bash completion script for factorix
        #
        # This command outputs a bash completion script that can be evaluated
        # to enable command-line completion for factorix.
        #
        # @example Enable completion in bash
        #   eval "$(factorix completion bash)"
        class Bash < Base
          # Path to bash completion script
          COMPLETION_SCRIPT_PATH = Pathname(__dir__).join("../../../../../completion/_factorix.bash").freeze
          private_constant :COMPLETION_SCRIPT_PATH

          desc "Generate bash completion script"

          example [
            "  # Output bash completion script",
            '  # Enable with: eval "$(factorix completion bash)"'
          ]

          # Execute the completion bash command
          #
          # @return [void]
          def call(**)
            raise Error, "Bash completion script not found" unless COMPLETION_SCRIPT_PATH.exist?

            puts COMPLETION_SCRIPT_PATH.read
          end
        end
      end
    end
  end
end
