# frozen_string_literal: true

require "json"

RSpec.describe Factorix::CLI::Commands::Path do
  let(:command) { Factorix::CLI::Commands::Path.new(runtime:) }

  let(:runtime) { instance_double(Factorix::Runtime::Base) }

  before do
    allow(runtime).to receive_messages(
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
    it "outputs all paths in table format by default" do
      output = capture_stdout { command.call(json: false) }

      expect(output).to include("executable_path")
      expect(output).to include("/path/to/factorio")
      expect(output).to include("user_dir")
      expect(output).to include("/path/to/user")
    end

    context "with --json option" do
      it "outputs all paths as JSON" do
        output = capture_stdout { command.call(json: true) }

        json = JSON.parse(output)
        expect(json).to include(
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
        )
      end
    end

    context "when runtime raises an error" do
      before do
        allow(runtime).to receive(:executable_path).and_raise(StandardError, "Runtime error")
      end

      it "re-raises the error" do
        expect { command.call(json: false) }.to raise_error(StandardError, "Runtime error")
      end
    end
  end
end
