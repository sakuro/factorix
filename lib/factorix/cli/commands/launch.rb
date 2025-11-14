# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      # Launch Factorio game
      #
      # This command launches the Factorio game executable with optional arguments.
      # By default, the game is launched asynchronously (in the background), but certain
      # options like --help and --dump-* are automatically detected and run synchronously.
      class Launch < Dry::CLI::Command
        # Game options that require synchronous execution
        #
        # These options output information and exit immediately, so we should
        # wait for them to complete rather than running them in the background.
        SYNCHRONOUS_OPTIONS = %w[
          --dump-data
          --dump-icon-sprites
          --dump-prototype-locale
          --help
          --version
        ].freeze
        private_constant :SYNCHRONOUS_OPTIONS

        # @!parse
        #   # @return [Runtime::Base]
        #   attr_reader :runtime
        #   # @return [Dry::Logger::Dispatcher]
        #   attr_reader :logger
        include Factorix::Import["runtime", "logger"]

        desc "Launch Factorio game"

        option :wait, type: :boolean, default: false, aliases: ["-w"], desc: "Wait for the game to finish"

        # Execute the launch command
        #
        # @param wait [Boolean] whether to wait for the game to finish
        # @param args [Array<String>] additional arguments to pass to Factorio
        # @return [void]
        def call(wait: false, args: [], **)
          logger.info("Launching Factorio", args:)

          # Detect if we should run synchronously based on the arguments
          async = args.none? {|arg| SYNCHRONOUS_OPTIONS.include?(arg) }

          begin
            runtime.launch(*args, async:)
            logger.info("Factorio launched successfully", async:)
          rescue => e
            logger.error("Failed to launch Factorio", error_class: e.class.name, error_message: e.message)
            raise
          end

          # If async and --wait is specified, wait for the game to start and finish
          return unless async && wait

          logger.debug("Waiting for game to start")
          wait_while { !runtime.running? }
          logger.debug("Game started, waiting for termination")
          wait_while { runtime.running? }
          logger.info("Game terminated")
        end

        # Wait while a condition is true
        #
        # @yield the condition to check
        # @return [void]
        private def wait_while
          loop do
            break unless yield

            sleep 1
          end
        end
      end
    end
  end
end
