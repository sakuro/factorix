# frozen_string_literal: true

module Factorix
  class Runtime
    # Linux runtime environment
    #
    # This is a partial implementation that only provides XDG directory support.
    # The user_dir and executable_path methods are not implemented because Factorio
    # can be installed in various locations on Linux (Steam, standalone, Flatpak,
    # Snap, etc.) and there is no standard path.
    #
    # Users must configure paths via the configuration file. See Runtime::UserConfigurable
    # for configuration instructions.
    class Linux < Base
      # Get the Factorio user directory path
      #
      # @return [Pathname] the Factorio user directory
      # @raise [NotImplementedError] Linux implementation requires configuration
      def user_dir
        raise NotImplementedError, "Auto-detection not supported on Linux"
      end

      # Get the Factorio executable path
      #
      # @return [Pathname] the Factorio executable path
      # @raise [NotImplementedError] Linux implementation requires configuration
      def executable_path
        raise NotImplementedError, "Auto-detection not supported on Linux"
      end
    end
  end
end
