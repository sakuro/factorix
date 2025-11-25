# frozen_string_literal: true

require "json"
require "open3"

module Factorix
  class Runtime
    # WSL (Windows Subsystem for Linux) runtime environment
    #
    # This implementation inherits from Windows and converts Windows paths
    # to WSL paths. It retrieves Windows environment variables via PowerShell
    # in a single batch operation and converts paths using native Ruby code.
    class WSL < Windows
      # Initialize WSL runtime environment
      #
      # @param path [WSLPath] the path provider (for dependency injection)
      def initialize(path: WSLPath.new) = super

      # WSL-specific path provider
      #
      # This class fetches Windows environment variables via PowerShell in one batch operation and converts Windows paths to WSL paths.
      class WSLPath
        # Default WSL mount root for Windows drives
        MOUNT_ROOT = "/mnt"
        private_constant :MOUNT_ROOT

        # PowerShell script to fetch Windows environment variables
        POWERSHELL_SCRIPT = <<~POWERSHELL
          [pscustomobject]@{
            "ProgramFiles(x86)" = ${Env:ProgramFiles(x86)};
            "APPDATA"           = ${Env:APPDATA};
            "LOCALAPPDATA"      = ${Env:LOCALAPPDATA}
          } | ConvertTo-Json -Compress
        POWERSHELL
        private_constant :POWERSHELL_SCRIPT

        # Fallback paths for powershell.exe when not found in PATH
        POWERSHELL_FALLBACK_PATHS = [
          "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
          "/mnt/c/Windows/system32/WindowsPowerShell/v1.0/powershell.exe"
        ].freeze
        private_constant :POWERSHELL_FALLBACK_PATHS

        # Initialize the path provider
        #
        # Sets up the mutex for thread-safe lazy initialization
        def initialize
          @mutex = Mutex.new
        end

        # Get the Program Files (x86) directory path (WSL-converted)
        #
        # @return [Pathname] the Program Files (x86) directory
        def program_files_x86 = @program_files_x86 ||= Pathname(convert_windows_to_wsl(windows_paths["ProgramFiles(x86)"]))

        # Get the AppData directory path (WSL-converted)
        #
        # @return [Pathname] the AppData directory
        def app_data = @app_data ||= Pathname(convert_windows_to_wsl(windows_paths["APPDATA"]))

        # Get the Local AppData directory path (WSL-converted)
        #
        # @return [Pathname] the Local AppData directory
        def local_app_data = @local_app_data ||= Pathname(convert_windows_to_wsl(windows_paths["LOCALAPPDATA"]))

        # Fetch and cache all Windows environment variables
        #
        # Retrieves Windows environment variables via PowerShell in a single execution. Called lazily on first path access and memoized.
        #
        # @return [Hash] the environment variables as a hash
        private def windows_paths
          return @windows_paths if @windows_paths

          @mutex.synchronize do
            @windows_paths ||= fetch_windows_paths_via_powershell
          end
        end

        # Fetch Windows environment variables via PowerShell
        #
        # Executes PowerShell once to retrieve all required environment variables as JSON, avoiding multiple cmd.exe invocations.
        #
        # @return [Hash] the environment variables as a hash
        # @raise [RuntimeError] if PowerShell execution fails
        private def fetch_windows_paths_via_powershell
          ps = find_powershell_exe

          # Use Open3.capture2 for safe command execution
          stdout, status = Open3.capture2(ps, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", POWERSHELL_SCRIPT)

          raise RuntimeError, "PowerShell execution failed: #{status}" unless status.success?

          JSON.parse(stdout.encode("UTF-8", invalid: :replace, undef: :replace))
        end

        # Convert Windows path to WSL path
        #
        # Converts Windows-style paths (e.g., "C:\Program Files") to WSL paths (e.g., "/mnt/c/Program Files")
        #
        # @param windows_path [String] Windows-style path to convert
        # @return [String] equivalent WSL path
        # @raise [ArgumentError] if the path format is invalid
        private def convert_windows_to_wsl(windows_path)
          raise ArgumentError, "Invalid Windows path: #{windows_path}" unless windows_path =~ %r{\A([A-Za-z]):[\\/]?(.*)\z}

          drive = $1.downcase
          path = $2.tr("\\", "/")
          result = "#{MOUNT_ROOT}/#{drive}/#{path}"
          # Normalize: collapse multiple slashes and remove trailing slash
          result.squeeze("/").delete_suffix("/")
        end

        # Find powershell.exe executable
        #
        # Searches for powershell.exe in PATH first, then falls back to typical absolute paths.
        #
        # @return [String] path to powershell.exe
        # @raise [RuntimeError] if powershell.exe is not found
        private def find_powershell_exe
          # Check if powershell.exe is in PATH
          return "powershell.exe" if system("which", "powershell.exe", out: File::NULL, err: File::NULL)

          # Fallback to absolute paths
          POWERSHELL_FALLBACK_PATHS.find {|path| File.exist?(path) } ||
            raise(RuntimeError, "powershell.exe not found in PATH or default locations")
        end
      end
    end
  end
end
