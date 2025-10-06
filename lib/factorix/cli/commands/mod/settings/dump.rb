# frozen_string_literal: true

require "dry/cli"
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
                mod_settings = Factorix::ModSettings.new(settings_path)
                output_toml(build_settings_hash(mod_settings))
              else
                puts "Settings file not found: #{settings_path}"
              end
            end

            # Output settings in TOML format
            # @param settings [Hash] The settings to output
            private def output_toml(settings)
              puts PerfectTOML.generate(settings)
            end

            # Build a hash suitable for TOML generation from MOD settings.
            #
            # @param mod_settings [ModSettings] The MOD settings.
            # @return [Hash] Hash suitable for TOML generation.
            private def build_settings_hash(mod_settings)
              result = {}

              mod_settings.each_section do |section|
                next if section.empty?

                result[section.name] = {}
                section.each do |key, value|
                  result[section.name][key] = value
                end
              end

              result
            end
          end
        end
      end
    end
  end
end
