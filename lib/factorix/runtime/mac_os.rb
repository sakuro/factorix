# frozen_string_literal: true

module Factorix
  class Runtime
    # macOS runtime environment
    #
    # This implementation assumes Factorio is installed via Steam.
    class MacOS < Base
      # Get the Factorio user directory path
      #
      # @return [Pathname] the Factorio user directory
      def user_dir
        Pathname(Dir.home).join("Library/Application Support/factorio")
      end

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
