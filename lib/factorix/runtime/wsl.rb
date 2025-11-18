# frozen_string_literal: true

module Factorix
  class Runtime
    # WSL (Windows Subsystem for Linux) runtime environment
    #
    # This implementation inherits from Windows and converts Windows paths
    # to WSL paths. It accesses Windows environment variables through cmd.exe
    # and uses wslpath to convert paths.
    class WSL < Windows
      # Initialize WSL runtime environment
      #
      # @param path [WSLPath] the path provider (for dependency injection)
      def initialize(path: WSLPath.new) = super

      # WSL-specific path provider
      class WSLPath
        # Get the Program Files (x86) directory path (WSL-converted)
        #
        # @return [Pathname] the Program Files (x86) directory
        def program_files_x86 = Pathname(wslpath(windows_env("ProgramFiles(x86)")))

        # Get the AppData directory path (WSL-converted)
        #
        # @return [Pathname] the AppData directory
        def app_data = Pathname(wslpath(windows_env("APPDATA")))

        # Get the Local AppData directory path (WSL-converted)
        #
        # @return [Pathname] the Local AppData directory
        def local_app_data = Pathname(wslpath(windows_env("LOCALAPPDATA")))

        # Get Windows environment variable value
        #
        # WSL cannot directly access Windows environment variables.
        # This method uses cmd.exe to echo the value of a Windows environment variable.
        #
        # @param name [String] the name of the Windows environment variable
        # @return [String] the value of the environment variable
        private def windows_env(name)
          system_drive = %x(wslvar SystemDrive).chomp
          windows_system_root = wslpath("#{system_drive}#{File::SEPARATOR}")

          IO.popen(["cmd.exe", "/C", "echo %#{name}%"], chdir: windows_system_root) do |io|
            io.gets.chomp
          end
        end

        # Convert Windows path to WSL path
        #
        # Windows paths cannot be directly used in WSL. This method uses the wslpath
        # utility to convert Windows-style paths to their WSL equivalents.
        # For example: "C:\Users" -> "/mnt/c/Users"
        #
        # @param path [String] Windows-style path to convert
        # @return [String] equivalent WSL path
        private def wslpath(path)
          %x(wslpath "#{path}").chomp
        end
      end
    end
  end
end
