# frozen_string_literal: true

RSpec.describe Factorix::Runtime::WSL::WSLPath do
  let(:wsl_path) { Factorix::Runtime::WSL::WSLPath.new }

  describe "#app_data" do
    before do
      allow(wsl_path).to receive(:windows_env).with("APPDATA").and_return("C:/Users/wube/AppData/Roaming")
      allow(wsl_path).to receive(:wslpath).with("C:/Users/wube/AppData/Roaming").and_return("/mnt/c/Users/wube/AppData/Roaming")
    end

    it "returns WSL-converted APPDATA path" do
      expect(wsl_path.app_data).to eq(Pathname("/mnt/c/Users/wube/AppData/Roaming"))
    end
  end

  describe "#local_app_data" do
    before do
      allow(wsl_path).to receive(:windows_env).with("LOCALAPPDATA").and_return("C:/Users/wube/AppData/Local")
      allow(wsl_path).to receive(:wslpath).with("C:/Users/wube/AppData/Local").and_return("/mnt/c/Users/wube/AppData/Local")
    end

    it "returns WSL-converted LOCALAPPDATA path" do
      expect(wsl_path.local_app_data).to eq(Pathname("/mnt/c/Users/wube/AppData/Local"))
    end
  end

  describe "#windows_env" do
    before do
      allow(wsl_path).to receive(:`).with("wslvar SystemDrive").and_return("C:\n")
      allow(wsl_path).to receive(:wslpath).with("C:/").and_return("/mnt/c")
      allow(IO).to receive(:popen).with(
        ["cmd.exe", "/C", "echo %APPDATA%"],
        {chdir: "/mnt/c"}
      ).and_yield(StringIO.new("C:/Users/wube/AppData/Roaming\n"))
    end

    it "retrieves Windows environment variable through cmd.exe" do
      expect(wsl_path.__send__(:windows_env, "APPDATA")).to eq("C:/Users/wube/AppData/Roaming")
    end
  end

  describe "#wslpath" do
    before do
      allow(wsl_path).to receive(:`).with('wslpath "C:/Users/wube"').and_return("/mnt/c/Users/wube\n")
    end

    it "converts Windows path to WSL path" do
      expect(wsl_path.__send__(:wslpath, "C:/Users/wube")).to eq("/mnt/c/Users/wube")
    end
  end
end
