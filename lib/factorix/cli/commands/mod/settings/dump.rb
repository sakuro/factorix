# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        module Settings
          # Dump MOD settings to TOML or JSON format
          class Dump < Dry::CLI::Command
            # @!parse
            #   # @return [MODSettings::CSVConverter]
            #   attr_reader :csv_converter
            #   # @return [MODSettings::JSONConverter]
            #   attr_reader :json_converter
            #   # @return [MODSettings::TOMLConverter]
            #   attr_reader :toml_converter
            #   # @return [Runtime::Base]
            #   attr_reader :runtime
            include Factorix::Import[
              csv_converter: "mod_settings_converters.csv",
              json_converter: "mod_settings_converters.json",
              toml_converter: "mod_settings_converters.toml",
              runtime: "runtime"
            ]

            desc "Dump MOD settings to TOML or JSON format"

            argument :settings_file, type: :string, required: false, desc: "Path to mod-settings.dat file"
            option :format, type: :string, default: "toml", values: %w[csv json toml], desc: "Output format"
            option :output, type: :string, aliases: ["-o"], desc: "Output file path"

            # Execute the dump command
            #
            # @param settings_file [String, nil] Path to mod-settings.dat file
            # @param format [String] Output format (toml or json)
            # @param output [String, nil] Output file path
            # @return [void]
            def call(settings_file: nil, format: "toml", output: nil, **)
              # Load MOD settings
              settings_path = settings_file ? Pathname(settings_file) : runtime.mod_settings_path
              settings = Factorix::MODSettings.load(from: settings_path)

              # Convert to specified format
              converter = converter_for_format(format)
              output_string = converter.convert_to(settings)

              # Write to output
              if output
                Pathname(output).write(output_string)
              else
                puts output_string
              end
            end

            private def converter_for_format(format)
              case format
              when "csv" then csv_converter
              when "json" then json_converter
              when "toml" then toml_converter
              else
                raise ArgumentError, "Unknown format: #{format}"
              end
            end
          end
        end
      end
    end
  end
end
