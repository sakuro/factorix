# frozen_string_literal: true

module Factorix
  class Runtime
    # Windows runtime environment
    #
    # This implementation uses Windows environment variables (APPDATA, LOCALAPPDATA)
    # to locate Factorio directories. It assumes Factorio is installed via Steam.
    # For other installation methods (GOG, itch.io, standalone), users should
    # configure the installation path in the Factorix configuration file.
    class Windows < Base
      # Initialize Windows runtime environment
      #
      # @param path [WindowsPath] the path provider (for dependency injection)
      def initialize(path: WindowsPath.new)
        super()
        @path = path
      end

      # Get the Factorio executable path
      #
      # Returns the default Steam installation path on Windows.
      #
      # @return [Pathname] the Factorio executable path
      def executable_path
        path.program_files_x86.join("Steam/steamapps/common/Factorio/bin/x64/factorio.exe")
      end

      # Get the Factorio user directory path
      #
      # @return [Pathname] the Factorio user directory
      def user_dir
        path.app_data.join("Factorio")
      end

      private attr_reader :path

      # Get the default cache home directory for Windows
      #
      # @return [Pathname] the default cache home directory
      private def default_cache_home_dir
        path.local_app_data
      end

      # Get the default config home directory for Windows
      #
      # @return [Pathname] the default config home directory
      private def default_config_home_dir
        path.app_data
      end

      # Get the default data home directory for Windows
      #
      # @return [Pathname] the default data home directory
      private def default_data_home_dir
        path.local_app_data
      end

      # Windows-specific path provider
      class WindowsPath
        # Get the Program Files (x86) directory path
        #
        # @return [Pathname] the Program Files (x86) directory
        def program_files_x86
          Pathname(convert_separator(ENV.fetch("ProgramFiles(x86)")))
        end

        # Get the AppData directory path
        #
        # @return [Pathname] the AppData directory
        def app_data
          Pathname(convert_separator(ENV.fetch("APPDATA")))
        end

        # Get the Local AppData directory path
        #
        # @return [Pathname] the Local AppData directory
        def local_app_data
          Pathname(convert_separator(ENV.fetch("LOCALAPPDATA")))
        end

        # Convert Windows path separators to forward slashes for aesthetics and consistency
        #
        # While Ruby accepts both separators, normalizing to forward slashes prevents
        # mixing backslashes and forward slashes when concatenating paths with Pathname#+,
        # which improves readability.
        #
        # @param path_string [String] the path string with backslashes
        # @return [String] the path string with forward slashes
        private def convert_separator(path_string)
          path_string.tr(File::ALT_SEPARATOR, File::SEPARATOR)
        end
      end
    end
  end
end
