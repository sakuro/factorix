# frozen_string_literal: true

require "dry/core/cache"
require_relative "windows"

module Factorix
  class Runtime
    # WSL runtime environment
    class WSL < Windows
      # Initialize WSL runtime environment
      def initialize(path: WSLPath.new)
        super()
        @path = path
      end

      private attr_reader :path

      GET_PROCESS_COMMAND = %[powershell.exe -Command "Get-Process factorio -ErrorAction SilentlyContinue"]
      private_constant :GET_PROCESS_COMMAND

      # Check if the game is running
      # @return [Boolean] true if the game is running, false otherwise
      def running?
        system(GET_PROCESS_COMMAND, out: IO::NULL)
        Process.last_status.exitstatus.zero?
      end

      # WSL specific path handling
      class WSLPath
        extend Dry::Core::Cache

        # Return the path to the user's AppData directory
        # @return [Pathname] path to the user's AppData directory
        def app_data = Pathname(wslpath(cmd_echo("APPDATA")))

        # Return the path to the Program Files (x86) directory
        # @return [Pathname] path to the Program Files (x86) directory
        def program_files_x86 = Pathname(wslpath(cmd_echo("ProgramFiles(x86)")))

        # Return the path to the user's Local AppData directory
        # @return [Pathname] path to the user's Local AppData directory
        def local_app_data = Pathname(wslpath(cmd_echo("LOCALAPPDATA")))

        # Retrieve Windows environment variables through cmd.exe
        #
        # WSL cannot directly access Windows environment variables.
        # This method uses cmd.exe to echo the value of a Windows environment variable.
        # The command is executed in the Windows system drive to ensure proper environment resolution.
        #
        # @param name [String] name of the Windows environment variable
        # @return [String] value of the environment variable
        private def cmd_echo(name)
          windows_system_root = wslpath(wslvar("SystemDrive") + File::SEPARATOR)
          fetch_or_store("cmd_echo", name) do
            IO.popen(%[cmd.exe /C "echo %#{name}%"], {chdir: windows_system_root}) do |io|
              io.gets.chomp
            end
          end
        end

        # Retrieve Windows system environment variables using wslvar
        #
        # The wslvar command is a WSL utility that provides access to certain Windows
        # system environment variables. It is primarily used to get basic system information
        # like SystemDrive, which is needed to properly execute cmd.exe commands.
        #
        # @param name [String] name of the Windows system environment variable
        # @return [String] value of the system environment variable
        private def wslvar(name)
          fetch_or_store("wslvar", name) do
            %x[wslvar #{name}].chomp
          end
        end

        # Convert Windows paths to WSL paths
        #
        # Windows paths cannot be directly used in WSL. This method uses the wslpath
        # utility to convert Windows-style paths to their WSL equivalents.
        # For example: "C:\Users" -> "/mnt/c/Users"
        #
        # @param path [String] Windows-style path to convert
        # @return [String] equivalent WSL path
        private def wslpath(path)
          fetch_or_store("wslpath", path) do
            %x[wslpath "#{path}"].chomp
          end
        end
      end
    end
  end
end
