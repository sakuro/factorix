# frozen_string_literal: true

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

  describe "#cache_dir" do
    subject(:cache_dir) { runtime.cache_dir }

    before do
      allow(ENV).to receive(:fetch).with("XDG_CACHE_HOME").and_return("/Users/wube/Library/Caches")
    end

    it "returns a path under ~/Library/Caches" do
      expect(cache_dir).to eq(Pathname("/Users/wube/Library/Caches/factorix"))
    end
  end
end
