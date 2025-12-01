# frozen_string_literal: true

RSpec.describe Factorix::Runtime::WSL::WSLPath do
  let(:wsl_path) { Factorix::Runtime::WSL::WSLPath.new }

  describe "lazy initialization" do
    before do
      allow(wsl_path).to receive(:fetch_windows_paths_via_powershell).and_return({
        "ProgramFiles(x86)" => "C:\\Program Files (x86)",
        "APPDATA" => "C:\\Users\\wube\\AppData\\Roaming",
        "LOCALAPPDATA" => "C:\\Users\\wube\\AppData\\Local"
      })
    end

    it "fetches and converts all paths on first access" do
      # Access all three properties
      expect(wsl_path.program_files_x86).to eq(Pathname("/mnt/c/Program Files (x86)"))
      expect(wsl_path.app_data).to eq(Pathname("/mnt/c/Users/wube/AppData/Roaming"))
      expect(wsl_path.local_app_data).to eq(Pathname("/mnt/c/Users/wube/AppData/Local"))
    end

    it "calls fetch_windows_paths_via_powershell only once for multiple accesses" do
      # Access all three properties
      wsl_path.program_files_x86
      wsl_path.app_data
      wsl_path.local_app_data

      # Verify it was called exactly once
      expect(wsl_path).to have_received(:fetch_windows_paths_via_powershell).once
    end

    it "is thread-safe and calls fetch_windows_paths_via_powershell only once from multiple threads" do
      call_count = 0
      allow(wsl_path).to receive(:fetch_windows_paths_via_powershell) do
        sleep 0.01 # Simulate slow PowerShell execution
        call_count += 1
        {
          "ProgramFiles(x86)" => "C:\\Program Files (x86)",
          "APPDATA" => "C:\\Users\\wube\\AppData\\Roaming",
          "LOCALAPPDATA" => "C:\\Users\\wube\\AppData\\Local"
        }
      end

      # Spawn multiple threads that all try to access paths simultaneously
      threads = Array.new(10) {
        Thread.new do
          wsl_path.program_files_x86
          wsl_path.app_data
          wsl_path.local_app_data
        end
      }

      threads.each(&:join)

      # Verify PowerShell was called exactly once despite concurrent access
      expect(call_count).to eq(1)
    end
  end

  describe "#app_data" do
    before do
      allow(wsl_path).to receive(:fetch_windows_paths_via_powershell).and_return({
        "ProgramFiles(x86)" => "C:\\Program Files (x86)",
        "APPDATA" => "C:\\Users\\wube\\AppData\\Roaming",
        "LOCALAPPDATA" => "C:\\Users\\wube\\AppData\\Local"
      })
    end

    it "returns WSL-converted APPDATA path" do
      expect(wsl_path.app_data).to eq(Pathname("/mnt/c/Users/wube/AppData/Roaming"))
    end
  end

  describe "#local_app_data" do
    before do
      allow(wsl_path).to receive(:fetch_windows_paths_via_powershell).and_return({
        "ProgramFiles(x86)" => "C:\\Program Files (x86)",
        "APPDATA" => "C:\\Users\\wube\\AppData\\Roaming",
        "LOCALAPPDATA" => "C:\\Users\\wube\\AppData\\Local"
      })
    end

    it "returns WSL-converted LOCALAPPDATA path" do
      expect(wsl_path.local_app_data).to eq(Pathname("/mnt/c/Users/wube/AppData/Local"))
    end
  end

  describe "#convert_windows_to_wsl" do
    it "converts Windows path with backslashes to WSL path" do
      expect(wsl_path.__send__(:convert_windows_to_wsl, "C:\\Users\\wube")).to eq("/mnt/c/Users/wube")
    end

    it "converts Windows path with forward slashes to WSL path" do
      expect(wsl_path.__send__(:convert_windows_to_wsl, "C:/Users/wube")).to eq("/mnt/c/Users/wube")
    end

    it "handles paths without trailing path separator" do
      expect(wsl_path.__send__(:convert_windows_to_wsl, "C:\\")).to eq("/mnt/c")
    end

    it "normalizes multiple slashes" do
      expect(wsl_path.__send__(:convert_windows_to_wsl, "C:\\Users\\\\wube")).to eq("/mnt/c/Users/wube")
    end

    it "handles drive letter only" do
      expect(wsl_path.__send__(:convert_windows_to_wsl, "D:")).to eq("/mnt/d")
    end

    it "raises ArgumentError for invalid path" do
      expect { wsl_path.__send__(:convert_windows_to_wsl, "invalid/path") }.to raise_error(Factorix::PlatformError, /Invalid Windows path/)
    end
  end

  describe "#fetch_windows_paths_via_powershell" do
    let(:json_output) { '{"ProgramFiles(x86)":"C:\\Program Files (x86)","APPDATA":"C:\\Users\\wube\\AppData\\Roaming","LOCALAPPDATA":"C:\\Users\\wube\\AppData\\Local"}' }
    let(:status) { instance_double(Process::Status, success?: true) }

    let(:wsl_path_for_fetch) do
      instance = Factorix::Runtime::WSL::WSLPath.new
      allow(instance).to receive(:find_powershell_exe).and_return("powershell.exe")
      allow(Open3).to receive(:capture2).and_return([json_output, status])
      instance
    end

    it "executes PowerShell and returns parsed JSON" do
      # Trigger lazy loading
      wsl_path_for_fetch.program_files_x86

      expect(Open3).to have_received(:capture2).with("powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", anything)
    end

    context "when PowerShell execution fails" do
      let(:status) { instance_double(Process::Status, success?: false, to_s: "exit 1") }

      it "raises an error" do
        expect { wsl_path_for_fetch.program_files_x86 }.to raise_error(Factorix::PlatformError, /PowerShell execution failed/)
      end
    end
  end

  describe "#find_powershell_exe" do
    context "when powershell.exe is in PATH" do
      it "returns 'powershell.exe'" do
        allow(wsl_path).to receive(:system).with("which", "powershell.exe", out: File::NULL, err: File::NULL).and_return(true)

        expect(wsl_path.__send__(:find_powershell_exe)).to eq("powershell.exe")
      end
    end

    context "when powershell.exe is not in PATH" do
      it "returns absolute path if found" do
        allow(wsl_path).to receive(:system).with("which", "powershell.exe", out: File::NULL, err: File::NULL).and_return(false)
        allow(File).to receive(:exist?).with("/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe").and_return(true)

        expect(wsl_path.__send__(:find_powershell_exe)).to eq("/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
      end

      it "raises error if not found anywhere" do
        allow(wsl_path).to receive(:system).with("which", "powershell.exe", out: File::NULL, err: File::NULL).and_return(false)
        allow(File).to receive(:exist?).and_return(false)

        expect { wsl_path.__send__(:find_powershell_exe) }.to raise_error(Factorix::PlatformError, /powershell.exe not found/)
      end
    end
  end
end
