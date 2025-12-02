# frozen_string_literal: true

require "json"

module Factorix
  class CLI
    module Commands
      module MOD
        module Settings
          # Restore MOD settings from JSON format
          class Restore < Base
            require_game_stopped!
            backup_support!

            # @!parse
            #   # @return [Runtime::Base]
            #   attr_reader :runtime
            include Import[:runtime]

            desc "Restore MOD settings from JSON format"

            example [
              "-i settings.json        # Restore from file",
              "                        # Restore from stdin"
            ]

            argument :settings_file, type: :string, required: false, desc: "Path to mod-settings.dat file to write"
            option :input, type: :string, aliases: ["-i"], desc: "Input file path"

            # Execute the restore command
            #
            # @param input [String, nil] Path to JSON file
            # @param settings_file [String, nil] Path to mod-settings.dat file
            # @return [void]
            def call(input: nil, settings_file: nil, **)
              # Read input
              if input
                input_path = Pathname(input)
                input_string = input_path.read
              else
                # Read from stdin
                input_string = $stdin.read
              end

              # Parse input
              data = JSON.parse(input_string)
              settings = build_settings(data)

              # Determine output path
              output_path = settings_file ? Pathname(settings_file) : runtime.mod_settings_path

              # Backup existing file if it exists
              backup_if_exists(output_path)

              # Save settings
              settings.save(output_path)
            end

            # Build MODSettings from parsed JSON data
            #
            # @param data [Hash] Parsed JSON data
            # @return [Factorix::MODSettings] The MOD settings
            private def build_settings(data)
              game_version = GameVersion.from_string(data["game_version"])
              sections = {}

              MODSettings::VALID_SECTIONS.each do |section_name|
                section = MODSettings::Section.new(section_name)
                if data.key?(section_name)
                  data[section_name].each do |key, value|
                    section[key] = convert_value_for_input(value)
                  end
                end
                sections[section_name] = section
              end

              MODSettings.new(game_version, sections)
            end

            # Convert value from JSON input (detect integer types)
            #
            # @param value [Object] The value to convert
            # @return [Object] Converted value
            # @note Factorio MOD settings use signed integers for int-setting type.
            #       Since JSON doesn't preserve signed/unsigned distinction,
            #       we use SignedInteger for all integer values.
            # @see https://wiki.factorio.com/Tutorial:Mod_settings#int-setting
            private def convert_value_for_input(value)
              case value
              when Integer
                SerDes::SignedInteger.new(value)
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
