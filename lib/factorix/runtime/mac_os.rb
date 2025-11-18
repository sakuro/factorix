# frozen_string_literal: true

module Factorix
  class Runtime
    # macOS runtime environment
    #
    # This implementation assumes Factorio is installed via Steam.
    # For other installation methods (GOG, itch.io, standalone), users should
    # configure the installation path in the Factorix configuration file.
    class MacOS < Base
      # Get the Factorio executable path
      #
      # Returns the default Steam installation path on macOS.
      #
      # @return [Pathname] the Factorio executable path
      def executable_path = Pathname(Dir.home).join("Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio")

      # Get the Factorio user directory path
      #
      # @return [Pathname] the Factorio user directory
      def user_dir = Pathname(Dir.home).join("Library/Application Support/factorio")

      # Get the Factorio data directory path
      #
      # This directory contains the base game data and built-in expansion MODs.
      #
      # @return [Pathname] the Factorio data directory
      def data_dir = Pathname(Dir.home).join("Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/data")

      # Get the Factorix log file path
      #
      # Returns the path to the Factorix log file using macOS convention.
      #
      # @return [Pathname] the Factorix log file path
      def factorix_log_path = Pathname(Dir.home).join("Library/Logs/factorix/factorix.log")
      # Get the default cache home directory for macOS
      #
      # @return [Pathname] the default cache home directory
      private def default_cache_home_dir
        Pathname(Dir.home).join("Library/Caches")
      end

      # Get the default config home directory for macOS
      #
      # @return [Pathname] the default config home directory
      private def default_config_home_dir
        Pathname(Dir.home).join("Library/Application Support")
      end

      # Get the default data home directory for macOS
      #
      # @return [Pathname] the default data home directory
      private def default_data_home_dir
        Pathname(Dir.home).join("Library/Application Support")
      end
    end
  end
end
