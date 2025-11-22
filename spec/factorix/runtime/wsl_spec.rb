# frozen_string_literal: true

RSpec.describe Factorix::Runtime::WSL do
  let(:runtime) { Factorix::Runtime::WSL.new(path:) }

  let(:path) {
    instance_double(
      Factorix::Runtime::WSL::WSLPath,
      app_data: Pathname("/mnt/c/Users/wube/AppData/Roaming"),
      local_app_data: Pathname("/mnt/c/Users/wube/AppData/Local")
    )
  }

  describe "#user_dir" do
    it "returns WSL-converted path to APPDATA/Factorio" do
      expect(runtime.user_dir).to eq(Pathname("/mnt/c/Users/wube/AppData/Roaming/Factorio"))
    end
  end

  describe "#mod_dir" do
    it "returns user_dir/mods" do
      expect(runtime.mod_dir).to eq(Pathname("/mnt/c/Users/wube/AppData/Roaming/Factorio/mods"))
    end
  end

  describe "#player_data_path" do
    it "returns user_dir/player-data.json" do
      expect(runtime.player_data_path).to eq(Pathname("/mnt/c/Users/wube/AppData/Roaming/Factorio/player-data.json"))
    end
  end

  describe "#xdg_cache_home_dir" do
    context "when XDG_CACHE_HOME is not set" do
      before do
        allow(ENV).to receive(:fetch).with("XDG_CACHE_HOME") {|_, &block| block.call }
      end

      it "returns WSL-converted LOCALAPPDATA" do
        expect(runtime.xdg_cache_home_dir).to eq(Pathname("/mnt/c/Users/wube/AppData/Local"))
      end
    end

    context "when XDG_CACHE_HOME is set" do
      before do
        allow(ENV).to receive(:fetch).with("XDG_CACHE_HOME").and_return("/home/wube/.cache")
      end

      it "returns the custom WSL path" do
        expect(runtime.xdg_cache_home_dir).to eq(Pathname("/home/wube/.cache"))
      end
    end
  end

  describe "#xdg_config_home_dir" do
    context "when XDG_CONFIG_HOME is not set" do
      before do
        allow(ENV).to receive(:fetch).with("XDG_CONFIG_HOME") {|_, &block| block.call }
      end

      it "returns WSL-converted APPDATA" do
        expect(runtime.xdg_config_home_dir).to eq(Pathname("/mnt/c/Users/wube/AppData/Roaming"))
      end
    end
  end

  describe "#xdg_data_home_dir" do
    context "when XDG_DATA_HOME is not set" do
      before do
        allow(ENV).to receive(:fetch).with("XDG_DATA_HOME") {|_, &block| block.call }
      end

      it "returns WSL-converted LOCALAPPDATA" do
        expect(runtime.xdg_data_home_dir).to eq(Pathname("/mnt/c/Users/wube/AppData/Local"))
      end
    end
  end
end
