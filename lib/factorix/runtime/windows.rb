# frozen_string_literal: true

require "pathname"

module Factorix
  class Runtime
    # Windows runtime environment
    class Windows < self
      # Initialize Windows runtime environment
      def initialize(path: WindowsPath.new)
        super()
        @path = path
      end

      private attr_reader :path

      # Return the path to the Factorio executable
      # @return [Pathname] path to the Factorio executable
      def executable
        path.program_files_x86 + "Steam/steamapps/common/Factorio/bin/x64/factorio.exe"
      end

      # Return the path to the user's Factorio directory
      # @return [Pathname] path to the user's Factorio directory
      def user_dir
        path.app_data + "Factorio"
      end

      # Return the path to the Factorio data directory
      # @return [Pathname] path to the Factorio data directory
      def data_dir
        path.program_files_x86 + "Steam/steamapps/common/Factorio/data"
      end

      # Return the path to the cache directory
      # @return [Pathname] path to the cache directory
      def cache_dir
        path.local_app_data + "factorix"
      end

      # Windows specific path handling
      class WindowsPath
        # Return the path to the user's AppData directory
        # @return [Pathname] path to the user's AppData directory
        def app_data = convert_env_path("APPDATA")

        # Return the path to the Program Files (x86) directory
        # @return [Pathname] path to the Program Files (x86) directory
        def program_files_x86 = convert_env_path("ProgramFiles(x86)")

        # Return the path to the user's Local AppData directory
        # @return [Pathname] path to the user's Local AppData directory
        def local_app_data = convert_env_path("LOCALAPPDATA")

        private def convert_env_path(name)
          Pathname(ENV.fetch(name).gsub(File::ALT_SEPARATOR, File::SEPARATOR))
        end
      end
    end
  end
end
