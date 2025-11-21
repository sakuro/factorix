# frozen_string_literal: true

require "json"

RSpec.describe Factorix::CLI::Commands::Path do
  subject(:command) { Factorix::CLI::Commands::Path.new(runtime: runtime_double) }

  let(:runtime_double) { instance_double(Factorix::Runtime::Base) }

  before do
    # Setup runtime method stubs
    allow(runtime_double).to receive_messages(
      executable_path: Pathname("/path/to/factorio"),
      user_dir: Pathname("/path/to/user"),
      mod_dir: Pathname("/path/to/mods"),
      save_dir: Pathname("/path/to/saves"),
      script_output_dir: Pathname("/path/to/script-output"),
      mod_list_path: Pathname("/path/to/mods/mod-list.json"),
      mod_settings_path: Pathname("/path/to/mods/mod-settings.dat"),
      player_data_path: Pathname("/path/to/user/player-data.json"),
      lock_path: Pathname("/path/to/user/.lock"),
      current_log_path: Pathname("/path/to/user/factorio-current.log"),
      previous_log_path: Pathname("/path/to/user/factorio-previous.log"),
      factorix_cache_dir: Pathname("/path/to/cache/factorix"),
      factorix_config_path: Pathname("/path/to/config/factorix/config.rb"),
      factorix_log_path: Pathname("/path/to/state/factorix/factorix.log")
    )
  end

  describe "#call" do
    context "with no path types" do
      it "outputs all paths" do
        output = capture_stdout { command.call(path_types: []) }
        result = JSON.parse(output)

        expect(result.keys).to match_array(
          %w[
            executable_path
            user_dir
            mod_dir
            save_dir
            script_output_dir
            mod_list_path
            mod_settings_path
            player_data_path
            lock_path
            current_log_path
            previous_log_path
            factorix_cache_dir
            factorix_config_path
            factorix_log_path
          ]
        )
      end
    end

    context "with a single valid path type" do
      it "outputs pretty JSON with the path" do
        output = capture_stdout { command.call(path_types: ["mod_dir"]) }
        result = JSON.parse(output)

        expect(result).to eq({
          "mod_dir" => "/path/to/mods"
        })
      end
    end

    context "with multiple valid path types" do
      it "outputs pretty JSON with all paths" do
        output = capture_stdout { command.call(path_types: %w[mod_dir user_dir]) }
        result = JSON.parse(output)

        expect(result).to eq({
          "mod_dir" => "/path/to/mods",
          "user_dir" => "/path/to/user"
        })
      end
    end

    context "with hyphen notation" do
      it "normalizes hyphens to underscores" do
        output = capture_stdout { command.call(path_types: ["mod-dir"]) }
        result = JSON.parse(output)

        expect(result).to eq({
          "mod_dir" => "/path/to/mods"
        })
      end
    end

    context "with all supported path types" do
      it "outputs pretty JSON with all paths" do
        path_types = %w[
          executable_path
          user_dir
          mod_dir
          save_dir
          script_output_dir
          mod_list_path
          mod_settings_path
          player_data_path
          lock_path
          current_log_path
          previous_log_path
          factorix_cache_dir
          factorix_config_path
          factorix_log_path
        ]

        output = capture_stdout { command.call(path_types:) }
        result = JSON.parse(output)

        expect(result).to eq({
          "executable_path" => "/path/to/factorio",
          "user_dir" => "/path/to/user",
          "mod_dir" => "/path/to/mods",
          "save_dir" => "/path/to/saves",
          "script_output_dir" => "/path/to/script-output",
          "mod_list_path" => "/path/to/mods/mod-list.json",
          "mod_settings_path" => "/path/to/mods/mod-settings.dat",
          "player_data_path" => "/path/to/user/player-data.json",
          "lock_path" => "/path/to/user/.lock",
          "current_log_path" => "/path/to/user/factorio-current.log",
          "previous_log_path" => "/path/to/user/factorio-previous.log",
          "factorix_cache_dir" => "/path/to/cache/factorix",
          "factorix_config_path" => "/path/to/config/factorix/config.rb",
          "factorix_log_path" => "/path/to/state/factorix/factorix.log"
        })
      end
    end

    context "with an unknown path type" do
      it "raises ArgumentError with available path types in bulleted format" do
        expect {
          capture_stdout { command.call(path_types: %w[mod_dir unknown_path user_dir]) }
        }.to raise_error(ArgumentError) do |error|
          expect(error.message).to include("Unknown path types:")
          expect(error.message).to include("- unknown_path")
          expect(error.message).to include("Available path types:")
          expect(error.message).to include("- executable_path")
          expect(error.message).to include("- mod_dir")
        end
      end
    end

    context "with only unknown path types" do
      it "raises ArgumentError listing all unknown types in bulleted format" do
        expect {
          capture_stdout { command.call(path_types: %w[invalid_type another_invalid]) }
        }.to raise_error(ArgumentError) do |error|
          expect(error.message).to include("Unknown path types:")
          expect(error.message).to include("- invalid_type")
          expect(error.message).to include("- another_invalid")
          expect(error.message).to include("Available path types:")
        end
      end
    end

    context "when runtime raises an error" do
      before do
        allow(runtime_double).to receive(:mod_dir).and_raise(StandardError, "Runtime error")
      end

      it "re-raises the error" do
        expect {
          capture_stdout { command.call(path_types: ["mod_dir"]) }
        }.to raise_error(StandardError, "Runtime error")
      end
    end
  end
end
