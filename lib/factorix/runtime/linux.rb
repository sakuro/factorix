# frozen_string_literal: true

module Factorix
  class Runtime
    # Linux runtime environment
    #
    # This is a partial implementation that only provides XDG directory support.
    # The user_dir method is not implemented because Factorio can be installed
    # in various locations on Linux (Steam, standalone, Flatpak, Snap, etc.)
    # and there is no standard path.
    #
    # Future implementation will support configuration file-based path specification
    # to allow users to specify their Factorio installation and user data locations.
    class Linux < Base
      # Get the Factorio user directory path
      #
      # @return [Pathname] the Factorio user directory
      # @raise [NotImplementedError] Linux implementation requires configuration
      def user_dir
        raise NotImplementedError, <<~MESSAGE
          Factorio user directory location varies on Linux.
          Future implementation will support configuration file-based path specification.
        MESSAGE
      end
    end
  end
end
