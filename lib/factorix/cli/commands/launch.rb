# frozen_string_literal: true

require "dry/cli"

module Factorix
  class CLI
    module Commands
      # Command for the launch subcommand
      class Launch < Dry::CLI::Command
        SYNCHRONOUS_OPTIONS = %w[
          --dump-data
          --dump-icon-sprites
          --dump-prototype-locale
          --help
        ].freeze
        private_constant :SYNCHRONOUS_OPTIONS

        desc "Launch the game"

        option :wait, type: :boolean, default: false, alias: ["w"], desc: "Wait for the game to finish"

        # Launch the game
        def call(args: [], **options)
          runtime = Factorix::Runtime.runtime
          async = args.none? {|arg| SYNCHRONOUS_OPTIONS.include?(arg) }

          runtime.launch(*args, async:)

          return unless async && options[:wait]

          wait_while { !runtime.running? }
          wait_while { runtime.running? }
        end

        private def wait_while(&)
          loop do
            break unless yield

            sleep 1
          end
        end
      end
    end
  end
end
