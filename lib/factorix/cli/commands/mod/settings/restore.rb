# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        module Settings
          # Restore MOD settings from TOML or JSON format
          class Restore < Dry::CLI::Command
            # @!parse
            #   # @return [MODSettings::JSONConverter]
            #   attr_reader :json_converter
            #   # @return [MODSettings::TOMLConverter]
            #   attr_reader :toml_converter
            #   # @return [Runtime::Base]
            #   attr_reader :runtime
            include Factorix::Import[
              json_converter: "mod_settings_converters.json",
              toml_converter: "mod_settings_converters.toml",
              runtime: "runtime"
            ]

            desc "Restore MOD settings from TOML or JSON format"

            argument :settings_file, type: :string, required: false, desc: "Path to mod-settings.dat file to write"
            option :input, type: :string, aliases: ["-i"], desc: "Input file path"
            option :backup_extension, type: :string, default: ".bak", desc: "Backup file extension"
            option :format, type: :string, values: %w[json toml], desc: "Input format (auto-detected from file extension if omitted, required when reading from stdin)"

            # Execute the restore command
            #
            # @param input [String, nil] Path to TOML or JSON file
            # @param settings_file [String, nil] Path to mod-settings.dat file
            # @param backup_extension [String] Backup file extension
            # @param format [String, nil] Input format
            # @return [void]
            def call(input: nil, settings_file: nil, backup_extension: ".bak", format: nil, **)
              # Read input
              if input
                input_path = Pathname(input)
                input_string = input_path.read
                detected_format = format || detect_format(input_path)
              else
                # Read from stdin
                raise ArgumentError, "--format option is required when reading from stdin" unless format

                input_string = $stdin.read
                detected_format = format
              end

              # Parse input
              converter = converter_for_format(detected_format)
              settings = converter.convert_from(input_string)

              # Determine output path
              output_path = settings_file ? Pathname(settings_file) : runtime.mod_settings_path

              # Backup existing file if it exists
              backup_if_exists(output_path, backup_extension)

              # Save settings
              settings.save(to: output_path)
            end

            private def converter_for_format(format)
              case format
              when "json" then json_converter
              when "toml" then toml_converter
              else
                raise ArgumentError, "Unknown format: #{format}"
              end
            end

            private def detect_format(path)
              case path.extname.downcase
              when ".toml" then "toml"
              when ".json" then "json"
              else
                raise ArgumentError, "Unknown format: #{path.extname}"
              end
            end

            # Backup existing file if it exists
            #
            # @param path [Pathname] File path to backup
            # @param extension [String] Backup extension
            # @return [void]
            private def backup_if_exists(path, extension)
              return unless path.exist?

              backup_path = Pathname("#{path}#{extension}")
              path.rename(backup_path)
            end
          end
        end
      end
    end
  end
end
