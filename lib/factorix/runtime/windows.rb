# frozen_string_literal: true

module Factorix
  class Runtime
    # Windows runtime environment
    #
    # This implementation uses Windows environment variables (APPDATA, LOCALAPPDATA)
    # to locate Factorio directories. It assumes Factorio is installed via Steam.
    class Windows < Base
      # Initialize Windows runtime environment
      #
      # @param path [WindowsPath] the path provider (for dependency injection)
      def initialize(path: WindowsPath.new)
        super()
        @path = path
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
        # Get the AppData directory path
        #
        # @return [Pathname] the AppData directory
        def app_data
          Pathname(ENV.fetch("APPDATA"))
        end

        # Get the Local AppData directory path
        #
        # @return [Pathname] the Local AppData directory
        def local_app_data
          Pathname(ENV.fetch("LOCALAPPDATA"))
        end
      end
    end
  end
end
