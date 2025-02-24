# frozen_string_literal: true

require "dry/core/cache"
require_relative "windows"

module Factorix
  class Runtime
    # WSL runtime environment
    class WSL < Windows
      extend Dry::Core::Cache

      # Initialize WSL runtime environment
      def initialize(path: WSLPath.new)
        super()
        @path = path
      end

      private attr_reader :path

      # WSL specific path handling
      class WSLPath
        # Return the path to the user's AppData directory
        # @return [Pathname] path to the user's AppData directory
        def app_data = Pathname(cmd_echo("APPDATA"))

        # Return the path to the Program Files (x86) directory
        def program_files_x86 = Pathname(cmd_echo("ProgramFiles(x86)"))

        private def cmd_echo(name)
          windows_system_root = wslpath(wslvar("SystemDrive") + File::ALT_SEPARATOR)
          fetch_or_store("cmd_echo", name) do
            IO.popen({chdir: windows_system_root}, %[cmd.exe /C "echo %#{name}%"]) do |io|
              io.gets.chomp
            end
          end
        end

        private def wslvar(name)
          fetch_or_store("wslvar", name) do
            %x[wslvar #{name}].chomp
          end
        end

        private def wslpath(path)
          fetch_or_store("wslpath", path) do
            %x[wslpath "#{path}"].chomp
          end
        end
      end
    end
  end
end
