# frozen_string_literal: true

RSpec.describe Factorix::Runtime::Windows::WindowsPath do
  let(:windows_path) { Factorix::Runtime::Windows::WindowsPath.new }

  describe "#app_data" do
    before do
      allow(ENV).to receive(:fetch).with("APPDATA").and_return("C:/Users/wube/AppData/Roaming")
    end

    it "returns APPDATA environment variable as Pathname" do
      expect(windows_path.app_data).to eq(Pathname("C:/Users/wube/AppData/Roaming"))
    end
  end

  describe "#local_app_data" do
    before do
      allow(ENV).to receive(:fetch).with("LOCALAPPDATA").and_return("C:/Users/wube/AppData/Local")
    end

    it "returns LOCALAPPDATA environment variable as Pathname" do
      expect(windows_path.local_app_data).to eq(Pathname("C:/Users/wube/AppData/Local"))
    end
  end
end
