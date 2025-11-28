# frozen_string_literal: true

module Factorix
  class Runtime
    # Linux runtime environment
    #
    # Provides default paths for Steam installation on Linux.
    # Users with non-Steam installations (standalone, Flatpak, Snap, etc.)
    # should configure paths via the configuration file.
    # See Runtime::UserConfigurable for configuration instructions.
    class Linux < Base
      # Get the Factorio executable path
      #
      # Returns the default Steam installation path on Linux.
      #
      # @return [Pathname] the Factorio executable path
      def executable_path = Pathname(Dir.home) + ".steam/steam/steamapps/common/Factorio/bin/x64/factorio"

      # Get the Factorio user directory path
      #
      # @return [Pathname] the Factorio user directory
      def user_dir = Pathname(Dir.home) + ".factorio"

      # Get the Factorio data directory path
      #
      # This directory contains the base game data and built-in expansion MODs.
      #
      # @return [Pathname] the Factorio data directory
      def data_dir = Pathname(Dir.home) + ".steam/steam/steamapps/common/Factorio/data"
    end
  end
end
