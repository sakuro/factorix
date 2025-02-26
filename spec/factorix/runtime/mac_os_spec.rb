# frozen_string_literal: true

# Load a mock of Sys::ProcTable before loading the Runtime::MacOS
# This is necessary in test because the Runtime::MacOS loads Sys::ProcTable if it's not already loaded
require "mocks/sys/proctable" unless RUBY_PLATFORM.include?("darwin")

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

  describe "#running?" do
    subject(:running?) { runtime.running? }

    before do
      allow(Sys::ProcTable).to receive(:ps).and_return(
        [
          Struct::ProcTableStruct.new(pid: 1, name: "factorio"),
          Struct::ProcTableStruct.new(pid: 2, name: "another_process")
        ]
      )
    end

    it "returns true if Factorio is running" do
      expect(running?).to be true
    end

    context "when Factorio is not running" do
      before do
        allow(Sys::ProcTable).to receive(:ps).and_return(
          [
            Struct::ProcTableStruct.new(pid: 1, name: "another_process"),
            Struct::ProcTableStruct.new(pid: 2, name: "yet_another_process")
          ]
        )
      end

      it "returns false" do
        expect(running?).to be false
      end
    end
  end
end
