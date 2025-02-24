# frozen_string_literal: true

require "factorix/runtime/wsl"

RSpec.describe Factorix::Runtime::WSL do
  subject(:runtime) { Factorix::Runtime::WSL.new(path:) }

  let(:path) {
    instance_double(
      Factorix::Runtime::WSL::WSLPath,
      app_data: Pathname("/mnt/c/Users/wube/AppData/Roaming"),
      program_files_x86: Pathname("/mnt/c/Program Files (x86)")
    )
  }

  describe "#executable" do
    subject(:executable) { runtime.executable }

    it "returns the path of Factorio executable" do
      expect(executable).to eq(Pathname("/mnt/c/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe"))
    end
  end

  describe "#user_dir" do
    subject(:user_dir) { runtime.user_dir }

    it "returns the path of Factorio user directory" do
      expect(user_dir).to eq(Pathname("/mnt/c/Users/wube/AppData/Roaming/Factorio"))
    end
  end

  describe "#data_dir" do
    subject(:data_dir) { runtime.data_dir }

    it "returns the path of Factorio data directory" do
      expect(data_dir).to eq(Pathname("/mnt/c/Program Files (x86)/Steam/steamapps/common/Factorio/data"))
    end
  end
end
