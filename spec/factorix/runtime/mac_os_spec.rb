# frozen_string_literal: true

RSpec.describe Factorix::Runtime::MacOS do
  let(:runtime) { Factorix::Runtime::MacOS.new }

  before do
    allow(Dir).to receive(:home).and_return("/Users/wube")
  end

  describe "#user_dir" do
    it "returns ~/Library/Application Support/factorio" do
      expect(runtime.user_dir).to eq(Pathname("/Users/wube/Library/Application Support/factorio"))
    end
  end

  describe "#mod_dir" do
    it "returns user_dir/mods" do
      expect(runtime.mod_dir).to eq(Pathname("/Users/wube/Library/Application Support/factorio/mods"))
    end
  end

  describe "#player_data_path" do
    it "returns user_dir/player-data.json" do
      expect(runtime.player_data_path).to eq(Pathname("/Users/wube/Library/Application Support/factorio/player-data.json"))
    end
  end

  describe "#xdg_cache_home_dir" do
    context "when XDG_CACHE_HOME is not set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_CACHE_HOME").and_return(false)
      end

      it "returns ~/Library/Caches" do
        expect(runtime.xdg_cache_home_dir).to eq(Pathname("/Users/wube/Library/Caches"))
      end
    end

    context "when XDG_CACHE_HOME is set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_CACHE_HOME").and_return(true)
        allow(ENV).to receive(:fetch).with("XDG_CACHE_HOME").and_return("/custom/cache")
      end

      it "returns the custom path" do
        expect(runtime.xdg_cache_home_dir).to eq(Pathname("/custom/cache"))
      end
    end
  end

  describe "#xdg_config_home_dir" do
    context "when XDG_CONFIG_HOME is not set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_CONFIG_HOME").and_return(false)
      end

      it "returns ~/Library/Application Support" do
        expect(runtime.xdg_config_home_dir).to eq(Pathname("/Users/wube/Library/Application Support"))
      end
    end
  end

  describe "#xdg_data_home_dir" do
    context "when XDG_DATA_HOME is not set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_DATA_HOME").and_return(false)
      end

      it "returns ~/Library/Application Support" do
        expect(runtime.xdg_data_home_dir).to eq(Pathname("/Users/wube/Library/Application Support"))
      end
    end
  end

  describe "#factorix_cache_dir" do
    context "when XDG_CACHE_HOME is not set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_CACHE_HOME").and_return(false)
      end

      it "returns ~/Library/Caches/factorix" do
        expect(runtime.factorix_cache_dir).to eq(Pathname("/Users/wube/Library/Caches/factorix"))
      end
    end
  end

  describe "#factorix_log_path" do
    it "returns ~/Library/Logs/factorix/factorix.log" do
      expect(runtime.factorix_log_path).to eq(Pathname("/Users/wube/Library/Logs/factorix/factorix.log"))
    end
  end
end
