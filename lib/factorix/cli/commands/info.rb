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
          puts "Platform: %p" % runtime.platform.to_s
          puts "Executable: %p" % runtime.executable.to_s
          puts "User directory: %p" % runtime.user_dir.to_s
          puts "Data directory: %p" % runtime.data_dir.to_s
          puts "Mod directory: %p" % runtime.mods_dir.to_s
          puts "Script output directory: %p" % runtime.script_output_dir.to_s
        end
      end
    end
  end
end
