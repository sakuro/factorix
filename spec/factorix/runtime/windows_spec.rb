# frozen_string_literal: true

require_relative "../../../lib/factorix/runtime/windows"

RSpec.describe Factorix::Runtime::Windows do
  subject(:runtime) { Factorix::Runtime::Windows.new(path:) }

  let(:path) {
    instance_double(
      Factorix::Runtime::Windows::WindowsPath,
      app_data: Pathname("C:/Users/wube/AppData/Roaming"),
      program_files_x86: Pathname("C:/Program Files (x86)"),
      local_app_data: Pathname("C:/Users/wube/AppData/Local")
    )
  }

  describe "#executable" do
    subject(:executable) { runtime.executable }

    it "returns the path of Factorio executable" do
      expect(executable).to eq(Pathname("C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe"))
    end
  end

  describe "#user_dir" do
    subject(:user_dir) { runtime.user_dir }

    it "returns the path of Factorio user directory" do
      expect(user_dir).to eq(Pathname("C:/Users/wube/AppData/Roaming/Factorio"))
    end
  end

  describe "#data_dir" do
    subject(:data_dir) { runtime.data_dir }

    it "returns the path of Factorio data directory" do
      expect(data_dir).to eq(Pathname("C:/Program Files (x86)/Steam/steamapps/common/Factorio/data"))
    end
  end

  describe "#cache_dir" do
    subject(:cache_dir) { runtime.cache_dir }

    it "returns a path under local_app_data" do
      expect(cache_dir).to eq(Pathname("C:/Users/wube/AppData/Local/factorix"))
    end
  end
end
