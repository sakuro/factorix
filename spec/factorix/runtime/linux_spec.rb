# frozen_string_literal: true

RSpec.describe Factorix::Runtime::Linux do
  let(:runtime) { Factorix::Runtime::Linux.new }

  describe "#user_dir" do
    it "raises NotImplementedError with explanation" do
      expect { runtime.user_dir }.to raise_error(NotImplementedError, /varies on Linux/)
    end
  end

  describe "#xdg_cache_home_dir" do
    context "when XDG_CACHE_HOME is not set" do
      before do
        allow(ENV).to receive(:key?).with("XDG_CACHE_HOME").and_return(false)
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
        allow(ENV).to receive(:key?).with("XDG_CONFIG_HOME").and_return(false)
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
        allow(ENV).to receive(:key?).with("XDG_DATA_HOME").and_return(false)
        allow(Dir).to receive(:home).and_return("/home/wube")
      end

      it "returns ~/.local/share" do
        expect(runtime.xdg_data_home_dir).to eq(Pathname("/home/wube/.local/share"))
      end
    end
  end
end
