# frozen_string_literal: true

RSpec.describe Factorix::Runtime::Windows::WindowsPath do
  let(:windows_path) { Factorix::Runtime::Windows::WindowsPath.new }

  before do
    # Stub File::ALT_SEPARATOR for non-Windows environments to test path separator conversion
    stub_const("File::ALT_SEPARATOR", "\\") unless File::ALT_SEPARATOR
  end

  describe "#program_files_x86" do
    before do
      allow(ENV).to receive(:fetch).with("ProgramFiles(x86)").and_return("C:\\Program Files (x86)")
    end

    it "returns ProgramFiles(x86) environment variable as Pathname with forward slashes" do
      expect(windows_path.program_files_x86).to eq(Pathname("C:/Program Files (x86)"))
    end
  end

  describe "#app_data" do
    before do
      allow(ENV).to receive(:fetch).with("APPDATA").and_return("C:\\Users\\wube\\AppData\\Roaming")
    end

    it "returns APPDATA environment variable as Pathname with forward slashes" do
      expect(windows_path.app_data).to eq(Pathname("C:/Users/wube/AppData/Roaming"))
    end
  end

  describe "#local_app_data" do
    before do
      allow(ENV).to receive(:fetch).with("LOCALAPPDATA").and_return("C:\\Users\\wube\\AppData\\Local")
    end

    it "returns LOCALAPPDATA environment variable as Pathname with forward slashes" do
      expect(windows_path.local_app_data).to eq(Pathname("C:/Users/wube/AppData/Local"))
    end
  end
end
