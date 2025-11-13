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
            executable-path
            user-dir
            mod-dir
            save-dir
            script-output-dir
            mod-list-path
            mod-settings-path
            player-data-path
            lock-path
            factorix-cache-dir
            factorix-config-path
            factorix-log-path
          ]
        )
      end
    end

    context "with a single valid path type" do
      it "outputs pretty JSON with the path" do
        output = capture_stdout { command.call(path_types: ["mod-dir"]) }
        result = JSON.parse(output)

        expect(result).to eq({
          "mod-dir" => "/path/to/mods"
        })
      end
    end

    context "with multiple valid path types" do
      it "outputs pretty JSON with all paths" do
        output = capture_stdout { command.call(path_types: %w[mod-dir user-dir]) }
        result = JSON.parse(output)

        expect(result).to eq({
          "mod-dir" => "/path/to/mods",
          "user-dir" => "/path/to/user"
        })
      end
    end

    context "with underscore notation" do
      it "normalizes underscores to hyphens" do
        output = capture_stdout { command.call(path_types: ["mod_dir"]) }
        result = JSON.parse(output)

        expect(result).to eq({
          "mod-dir" => "/path/to/mods"
        })
      end
    end

    context "with all supported path types" do
      it "outputs pretty JSON with all paths" do
        path_types = %w[
          executable-path
          user-dir
          mod-dir
          save-dir
          script-output-dir
          mod-list-path
          mod-settings-path
          player-data-path
          lock-path
          factorix-cache-dir
          factorix-config-path
          factorix-log-path
        ]

        output = capture_stdout { command.call(path_types:) }
        result = JSON.parse(output)

        expect(result).to eq({
          "executable-path" => "/path/to/factorio",
          "user-dir" => "/path/to/user",
          "mod-dir" => "/path/to/mods",
          "save-dir" => "/path/to/saves",
          "script-output-dir" => "/path/to/script-output",
          "mod-list-path" => "/path/to/mods/mod-list.json",
          "mod-settings-path" => "/path/to/mods/mod-settings.dat",
          "player-data-path" => "/path/to/user/player-data.json",
          "lock-path" => "/path/to/user/.lock",
          "factorix-cache-dir" => "/path/to/cache/factorix",
          "factorix-config-path" => "/path/to/config/factorix/config.rb",
          "factorix-log-path" => "/path/to/state/factorix/factorix.log"
        })
      end
    end

    context "with an unknown path type" do
      it "raises ArgumentError with available path types in bulleted format" do
        expect {
          command.call(path_types: %w[mod-dir unknown-path user-dir])
        }.to raise_error(ArgumentError) do |error|
          expect(error.message).to include("Unknown path types:")
          expect(error.message).to include("- unknown-path")
          expect(error.message).to include("Available path types:")
          expect(error.message).to include("- executable-path")
          expect(error.message).to include("- mod-dir")
        end
      end
    end

    context "with only unknown path types" do
      it "raises ArgumentError listing all unknown types in bulleted format" do
        expect {
          command.call(path_types: %w[invalid-type another-invalid])
        }.to raise_error(ArgumentError) do |error|
          expect(error.message).to include("Unknown path types:")
          expect(error.message).to include("- invalid-type")
          expect(error.message).to include("- another-invalid")
          expect(error.message).to include("Available path types:")
        end
      end
    end

    context "when runtime raises an error" do
      before do
        allow(runtime_double).to receive(:mod_dir).and_raise(StandardError, "Runtime error")
      end

      it "re-raises the error" do
        expect { command.call(path_types: ["mod-dir"]) }.to raise_error(StandardError, "Runtime error")
      end
    end
  end
end
