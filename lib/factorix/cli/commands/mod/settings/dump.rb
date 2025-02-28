# frozen_string_literal: true

require "dry/cli"
require "factorix"
require "pathname"
require "perfect_toml"

module Factorix
  class CLI
    module Commands
      module Mod
        module Settings
          # Command for dumping MOD settings
          class Dump < Dry::CLI::Command
            desc "Dump MOD settings in TOML format"

            # Dump MOD settings
            # @param _options [Hash] The options for the command (unused)
            def call(**_options)
              runtime = Factorix::Runtime.runtime
              settings_path = runtime.mod_settings_path

              if settings_path.exist?
                settings = parse_settings_file(settings_path)
                output_toml(settings)
              else
                puts "Settings file not found: #{settings_path}"
              end
            end

            private def output_toml(settings)
              puts PerfectTOML.generate(settings)
            end

            # Parse the mod settings file
            # @param settings_path [Pathname] Path to the mod settings file
            # @return [Hash] Parsed settings
            # @raise [RuntimeError] If there's an error parsing the file
            private def parse_settings_file(settings_path)
              settings_path.open("rb") do |file|
                deserializer = Factorix::Deserializer.new(file)

                # 1. Read version64
                deserializer.read_version64

                # 2. Skip a boolean value
                deserializer.read_bool

                # 3. Read property tree
                deserializer.read_property_tree
              end
            end
          end
        end
      end
    end
  end
end
