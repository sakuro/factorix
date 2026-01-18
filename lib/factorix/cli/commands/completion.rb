# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      # Generate shell completion script for factorix
      #
      # This command outputs a shell completion script that can be evaluated
      # to enable command-line completion for factorix.
      #
      # @example Enable completion (auto-detect shell)
      #   eval "$(factorix completion)"
      # @example Enable completion for specific shell
      #   eval "$(factorix completion zsh)"
      class Completion < Base
        # Directory containing completion scripts
        COMPLETION_DIR = Pathname(__dir__).join("../../../../completion").freeze
        private_constant :COMPLETION_DIR

        # Supported shells and their script filenames
        SUPPORTED_SHELLS = {
          "bash" => "_factorix.bash",
          "fish" => "_factorix.fish",
          "zsh" => "_factorix.zsh"
        }.freeze
        private_constant :SUPPORTED_SHELLS

        desc "Generate shell completion script"

        argument :shell,
          required: false,
          values: [nil] + SUPPORTED_SHELLS.keys,
          desc: "Shell type. Defaults to current shell from $SHELL"

        example [
          "            # Output completion script for current shell",
          "bash        # Output bash completion script",
          "fish        # Output fish completion script",
          "zsh         # Output zsh completion script"
        ]

        # Execute the completion command
        #
        # @param shell [String, nil] Shell type (zsh, bash, fish)
        # @return [void]
        # @raise [InvalidArgumentError] if shell type cannot be detected or is unsupported
        # @raise [ConfigurationError] if completion script not found
        def call(shell: nil, **)
          shell_type = shell || detect_shell
          validate_shell!(shell_type)

          script_path = COMPLETION_DIR / SUPPORTED_SHELLS[shell_type]
          raise ConfigurationError, "#{shell_type.capitalize} completion script not found" unless script_path.exist?

          puts script_path.read
        end

        # Detect shell type from SHELL environment variable
        #
        # @return [String] Detected shell type
        private def detect_shell
          shell_path = ENV.fetch("SHELL", "")
          shell_name = File.basename(shell_path)

          return shell_name if SUPPORTED_SHELLS.key?(shell_name)

          raise InvalidArgumentError, "Cannot detect shell type from SHELL=#{shell_path}. Please specify: #{SUPPORTED_SHELLS.keys.join(", ")}"
        end

        # Validate shell type
        #
        # @param shell [String] Shell type to validate
        # @raise [InvalidArgumentError] If shell type is not supported
        private def validate_shell!(shell)
          return if SUPPORTED_SHELLS.key?(shell)

          raise InvalidArgumentError, "Unsupported shell: #{shell}. Supported shells: #{SUPPORTED_SHELLS.keys.join(", ")}"
        end
      end
    end
  end
end
