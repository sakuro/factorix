# frozen_string_literal: true

require "dry/cli"

require_relative "../../runtime"

module Factorix
  class CLI
    module Commands
      # Command for the info subcommand
      class Info < Dry::CLI::Command
        desc "Display information about the Factorio runtime environment"

        # Display runtime information
        def call(**)
          runtime = Factorix::Runtime.runtime
          display_runtime_info(runtime)
        end

        private def display_runtime_info(runtime)
          info_items(runtime).each do |label, value|
            display_item(label, value)
          end
        end

        private def info_items(runtime)
          {
            "Executable" => runtime.executable,
            "User directory" => runtime.user_dir,
            "Data directory" => runtime.data_dir,
            "Mod directory" => runtime.mods_dir,
            "Script output directory" => runtime.script_output_dir
          }
        end

        private def display_item(label, value)
          puts "#{label}: %s" % value
        end
      end
    end
  end
end
