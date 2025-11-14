# frozen_string_literal: true

RSpec.describe Factorix::Runtime::Base do
  let(:runtime) { Factorix::Runtime::Base.new }

  describe "#user_dir" do
    it "raises NotImplementedError" do
      expect { runtime.user_dir }.to raise_error(NotImplementedError, /user_dir is not implemented/)
    end
  end

  describe "#mod_dir" do
    context "when user_dir is implemented" do
      before do
        allow(runtime).to receive(:user_dir).and_return(Pathname("/home/wube/.factorio"))
      end

      it "returns user_dir + mods" do
        expect(runtime.mod_dir).to eq(Pathname("/home/wube/.factorio/mods"))
      end
    end
  end

  describe "#mod_list_path" do
    context "when user_dir is implemented" do
      before do
        allow(runtime).to receive(:user_dir).and_return(Pathname("/home/wube/.factorio"))
      end

      it "returns mod_dir + mod-list.json" do
        expect(runtime.mod_list_path).to eq(Pathname("/home/wube/.factorio/mods/mod-list.json"))
      end
    end
  end

  describe "#mod_settings_path" do
    context "when mod_dir is implemented" do
      before do
        allow(runtime).to receive(:mod_dir).and_return(Pathname("/home/wube/.factorio/mods"))
      end

      it "returns mod_dir + mod-settings.dat" do
        expect(runtime.mod_settings_path).to eq(Pathname("/home/wube/.factorio/mods/mod-settings.dat"))
      end
    end
  end

  describe "#player_data_path" do
    context "when user_dir is implemented" do
      before do
        allow(runtime).to receive(:user_dir).and_return(Pathname("/home/wube/.factorio"))
      end

      it "returns user_dir + player-data.json" do
        expect(runtime.player_data_path).to eq(Pathname("/home/wube/.factorio/player-data.json"))
      end
    end
  end

  describe "#current_log_path" do
    context "when user_dir is implemented" do
      before do
        allow(runtime).to receive(:user_dir).and_return(Pathname("/home/wube/.factorio"))
      end

      it "returns user_dir + factorio-current.log" do
        expect(runtime.current_log_path).to eq(Pathname("/home/wube/.factorio/factorio-current.log"))
      end
    end
  end

  describe "#previous_log_path" do
    context "when user_dir is implemented" do
      before do
        allow(runtime).to receive(:user_dir).and_return(Pathname("/home/wube/.factorio"))
      end

      it "returns user_dir + factorio-previous.log" do
        expect(runtime.previous_log_path).to eq(Pathname("/home/wube/.factorio/factorio-previous.log"))
      end
    end
  end

  describe "#xdg_cache_home_dir" do
    context "when XDG_CACHE_HOME is set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_CACHE_HOME").and_return(true)
        allow(ENV).to receive(:fetch).with("XDG_CACHE_HOME").and_return("/custom/cache")
      end

      it "returns the value from environment variable" do
        expect(runtime.xdg_cache_home_dir).to eq(Pathname("/custom/cache"))
      end
    end

    context "when XDG_CACHE_HOME is not set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_CACHE_HOME").and_return(false)
        allow(Dir).to receive(:home).and_return("/home/wube")
      end

      it "returns default cache directory" do
        expect(runtime.xdg_cache_home_dir).to eq(Pathname("/home/wube/.cache"))
      end
    end
  end

  describe "#xdg_config_home_dir" do
    context "when XDG_CONFIG_HOME is set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_CONFIG_HOME").and_return(true)
        allow(ENV).to receive(:fetch).with("XDG_CONFIG_HOME").and_return("/custom/config")
      end

      it "returns the value from environment variable" do
        expect(runtime.xdg_config_home_dir).to eq(Pathname("/custom/config"))
      end
    end

    context "when XDG_CONFIG_HOME is not set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_CONFIG_HOME").and_return(false)
        allow(Dir).to receive(:home).and_return("/home/wube")
      end

      it "returns default config directory" do
        expect(runtime.xdg_config_home_dir).to eq(Pathname("/home/wube/.config"))
      end
    end
  end

  describe "#xdg_data_home_dir" do
    context "when XDG_DATA_HOME is set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_DATA_HOME").and_return(true)
        allow(ENV).to receive(:fetch).with("XDG_DATA_HOME").and_return("/custom/data")
      end

      it "returns the value from environment variable" do
        expect(runtime.xdg_data_home_dir).to eq(Pathname("/custom/data"))
      end
    end

    context "when XDG_DATA_HOME is not set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_DATA_HOME").and_return(false)
        allow(Dir).to receive(:home).and_return("/home/wube")
      end

      it "returns default data directory" do
        expect(runtime.xdg_data_home_dir).to eq(Pathname("/home/wube/.local/share"))
      end
    end
  end

  describe "#xdg_state_home_dir" do
    context "when XDG_STATE_HOME is set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_STATE_HOME").and_return(true)
        allow(ENV).to receive(:fetch).with("XDG_STATE_HOME").and_return("/custom/state")
      end

      it "returns the value from environment variable" do
        expect(runtime.xdg_state_home_dir).to eq(Pathname("/custom/state"))
      end
    end

    context "when XDG_STATE_HOME is not set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_STATE_HOME").and_return(false)
        allow(Dir).to receive(:home).and_return("/home/wube")
      end

      it "returns default state directory" do
        expect(runtime.xdg_state_home_dir).to eq(Pathname("/home/wube/.local/state"))
      end
    end
  end

  describe "#factorix_cache_dir" do
    before do
      allow(runtime).to receive(:xdg_cache_home_dir).and_return(Pathname("/home/wube/.cache"))
    end

    it "returns xdg_cache_home_dir / factorix" do
      expect(runtime.factorix_cache_dir).to eq(Pathname("/home/wube/.cache/factorix"))
    end
  end

  describe "#factorix_config_path" do
    before do
      allow(runtime).to receive(:xdg_config_home_dir).and_return(Pathname("/home/wube/.config"))
    end

    it "returns xdg_config_home_dir / factorix / config.rb" do
      expect(runtime.factorix_config_path).to eq(Pathname("/home/wube/.config/factorix/config.rb"))
    end
  end

  describe "#factorix_log_path" do
    before do
      allow(runtime).to receive(:xdg_state_home_dir).and_return(Pathname("/home/wube/.local/state"))
    end

    it "returns xdg_state_home_dir / factorix / factorix.log" do
      expect(runtime.factorix_log_path).to eq(Pathname("/home/wube/.local/state/factorix/factorix.log"))
    end
  end

  describe "#launch" do
    before do
      allow(runtime).to receive_messages(executable_path: Pathname("/usr/games/factorio/bin/x64/factorio"), running?: false)
    end

    context "when launching asynchronously" do
      it "launches with stdout discarded" do
        allow(runtime).to receive(:spawn)

        runtime.launch(async: true)

        expect(runtime).to have_received(:spawn).with(
          ["/usr/games/factorio/bin/x64/factorio", "factorio"],
          out: IO::NULL
        )
      end

      it "passes arguments to the executable" do
        allow(runtime).to receive(:spawn)

        runtime.launch("--start-server", "save.zip", async: true)

        expect(runtime).to have_received(:spawn).with(
          ["/usr/games/factorio/bin/x64/factorio", "factorio"],
          "--start-server",
          "save.zip",
          out: IO::NULL
        )
      end
    end

    context "when launching synchronously" do
      it "launches without discarding stdout" do
        allow(runtime).to receive(:system) do |*_args|
          $stdout.puts "Factorio output"
          true
        end

        expect { runtime.launch(async: false) }.to output(/Factorio output/).to_stdout

        expect(runtime).to have_received(:system).with(
          ["/usr/games/factorio/bin/x64/factorio", "factorio"]
        )
      end

      it "passes arguments to the executable" do
        allow(runtime).to receive(:system) do |*_args|
          $stdout.puts "Usage: factorio [OPTIONS]"
          true
        end

        expect { runtime.launch("--help", async: false) }.to output(/Usage: factorio/).to_stdout

        expect(runtime).to have_received(:system).with(
          ["/usr/games/factorio/bin/x64/factorio", "factorio"],
          "--help"
        )
      end

      it "allows --version output to be displayed" do
        allow(runtime).to receive(:system) do |*_args|
          $stdout.puts "Factorio 1.1.100"
          true
        end

        expect { runtime.launch("--version", async: false) }.to output(/Factorio 1\.1\.100/).to_stdout

        expect(runtime).to have_received(:system).with(
          ["/usr/games/factorio/bin/x64/factorio", "factorio"],
          "--version"
        )
      end
    end

    context "when the game is already running" do
      before do
        allow(runtime).to receive(:running?).and_return(true)
      end

      it "raises RuntimeError" do
        expect { runtime.launch }.to raise_error(RuntimeError, "The game is already running")
      end
    end
  end
end
