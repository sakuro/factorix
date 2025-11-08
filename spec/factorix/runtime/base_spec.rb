# frozen_string_literal: true

RSpec.describe Factorix::Runtime::Base do
  let(:runtime) { Factorix::Runtime::Base.new }

  describe "#user_dir" do
    it "raises NotImplementedError" do
      expect { runtime.user_dir }.to raise_error(NotImplementedError, /user_dir is not implemented/)
    end
  end

  describe "#mods_dir" do
    context "when user_dir is implemented" do
      before do
        allow(runtime).to receive(:user_dir).and_return(Pathname("/home/wube/.factorio"))
      end

      it "returns user_dir + mods" do
        expect(runtime.mods_dir).to eq(Pathname("/home/wube/.factorio/mods"))
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
end
