# frozen_string_literal: true

require "dry/cli"
require "factorix"
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

              if File.exist?(settings_path)
                # バイナリ解析部分は後で実装
                # 現時点ではダミーデータを出力
                output_toml(create_dummy_settings)
              else
                puts "Settings file not found: #{settings_path}"
              end
            end

            private def output_toml(settings)
              puts PerfectTOML.generate(settings)
            end

            # Create dummy settings for testing
            # @return [Hash] Dummy settings
            private def create_dummy_settings
              {
                "mod-setting" => {
                  "startup" => {},
                  "runtime-global" => {},
                  "runtime-per-user" => {}
                }
              }
            end
          end
        end
      end
    end
  end
end
