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
            "Platform" => runtime.platform.to_s,
            "Executable" => runtime.executable.to_s,
            "User directory" => runtime.user_dir.to_s,
            "Data directory" => runtime.data_dir.to_s,
            "Mod directory" => runtime.mods_dir.to_s,
            "Script output directory" => runtime.script_output_dir.to_s
          }
        end

        private def display_item(label, value)
          puts "#{label}: %p" % value
        end
      end
    end
  end
end
