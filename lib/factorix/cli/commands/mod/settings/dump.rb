# frozen_string_literal: true

require "json"

module Factorix
  class CLI
    module Commands
      module MOD
        module Settings
          # Dump MOD settings to JSON format
          class Dump < Base
            # @!parse
            #   # @return [Runtime::Base]
            #   attr_reader :runtime
            include Import[:runtime]

            desc "Dump MOD settings to JSON format"

            example [
              "                        # Dump to stdout",
              "-o settings.json        # Dump to file",
              "/path/to/mod-settings.dat -o out.json   # Dump specific file"
            ]

            argument :settings_file, type: :string, required: false, desc: "Path to mod-settings.dat file"
            option :output, type: :string, aliases: ["-o"], desc: "Output file path"

            # Execute the dump command
            #
            # @param settings_file [String, nil] Path to mod-settings.dat file
            # @param output [String, nil] Output file path
            # @return [void]
            def call(settings_file: nil, output: nil, **)
              # Load MOD settings
              settings_path = settings_file ? Pathname(settings_file) : runtime.mod_settings_path
              settings = MODSettings.load(settings_path)

              # Convert to JSON format
              data = build_hash(settings)
              output_string = JSON.pretty_generate(data)

              # Write to output
              if output
                Pathname(output).write(output_string)
              else
                puts output_string
              end
            end

            # Build hash from MODSettings for JSON output
            #
            # @param settings [Factorix::MODSettings] The MOD settings to convert
            # @return [Hash] Hash representation of the settings
            private def build_hash(settings)
              result = {
                "game_version" => settings.game_version.to_s
              }

              settings.each_section do |section|
                section_hash = {}
                section.each do |key, value|
                  section_hash[key] = convert_value_for_output(value)
                end
                result[section.name] = section_hash unless section_hash.empty?
              end

              result
            end

            # Convert value for JSON output (handle SignedInteger/UnsignedInteger)
            #
            # @param value [Object] The value to convert
            # @return [Object] Converted value
            private def convert_value_for_output(value)
              case value
              when Types::SignedInteger, Types::UnsignedInteger
                # Integer(...) does not accept Integer instance
                Integer(value.to_s, 10)
              else
                value
              end
            end
          end
        end
      end
    end
  end
end
