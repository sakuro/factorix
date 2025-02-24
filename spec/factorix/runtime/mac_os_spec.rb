# frozen_string_literal: true

require "factorix/runtime/mac_os"

RSpec.describe Factorix::Runtime::MacOS do
  let(:runtime) { Factorix::Runtime::MacOS.new }

  before do
    allow(Dir).to receive(:home).and_return("/Users/wube")
  end

  describe "#executable" do
    subject(:executable) { runtime.executable }

    it "returns the path of Factorio executable" do
      expect(executable).to eq(
        Pathname(
          "/Users/wube/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio"
        )
      )
    end
  end

  describe "#user_dir" do
    subject(:user_dir) { runtime.user_dir }

    it "returns the path of Factorio user directory" do
      expect(user_dir).to eq(Pathname("/Users/wube/Library/Application Support/Factorio"))
    end
  end

  describe "#data_dir" do
    subject(:data_dir) { runtime.data_dir }

    it "returns the path of Factorio data directory" do
      expect(data_dir).to eq(
        Pathname("/Users/wube/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/data")
      )
    end
  end
end
