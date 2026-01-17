# frozen_string_literal: true

RSpec.describe Factorix::Runtime::Linux do
  let(:runtime) { Factorix::Runtime::Linux.new }
  let(:logger) { instance_double(Dry::Logger::Dispatcher) }

  before do
    allow(Factorix::Container).to receive(:[]).with(:logger).and_return(logger)
    allow(Factorix::Container).to receive(:[]).with(:runtime).and_return(runtime)
    allow(logger).to receive(:debug)
    allow(logger).to receive(:error)
  end

  describe "#executable_path" do
    before { allow(Dir).to receive(:home).and_return("/home/wube") }

    it "returns the Steam installation path" do
      expect(runtime.executable_path).to eq(Pathname("/home/wube/.steam/steam/steamapps/common/Factorio/bin/x64/factorio"))
    end
  end

  describe "#user_dir" do
    before { allow(Dir).to receive(:home).and_return("/home/wube") }

    it "returns ~/.factorio" do
      expect(runtime.user_dir).to eq(Pathname("/home/wube/.factorio"))
    end
  end

  describe "#data_dir" do
    before { allow(Dir).to receive(:home).and_return("/home/wube") }

    it "returns the Steam data directory path" do
      expect(runtime.data_dir).to eq(Pathname("/home/wube/.steam/steam/steamapps/common/Factorio/data"))
    end
  end

  describe "#xdg_cache_home_dir" do
    context "when XDG_CACHE_HOME is not set" do
      before do
        allow(ENV).to receive(:fetch).with("XDG_CACHE_HOME") {|_, &block| block.call }
        allow(Dir).to receive(:home).and_return("/home/wube")
      end

      it "returns ~/.cache" do
        expect(runtime.xdg_cache_home_dir).to eq(Pathname("/home/wube/.cache"))
      end
    end
  end

  describe "#xdg_config_home_dir" do
    context "when XDG_CONFIG_HOME is not set" do
      before do
        allow(ENV).to receive(:fetch).with("XDG_CONFIG_HOME") {|_, &block| block.call }
        allow(Dir).to receive(:home).and_return("/home/wube")
      end

      it "returns ~/.config" do
        expect(runtime.xdg_config_home_dir).to eq(Pathname("/home/wube/.config"))
      end
    end
  end

  describe "#xdg_data_home_dir" do
    context "when XDG_DATA_HOME is not set" do
      before do
        allow(ENV).to receive(:fetch).with("XDG_DATA_HOME") {|_, &block| block.call }
        allow(Dir).to receive(:home).and_return("/home/wube")
      end

      it "returns ~/.local/share" do
        expect(runtime.xdg_data_home_dir).to eq(Pathname("/home/wube/.local/share"))
      end
    end
  end
end
