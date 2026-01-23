# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      # Provides lazy Portal resolution for CLI commands
      #
      # This module defers Portal dependency resolution until first use,
      # allowing configuration to be loaded before cache backends are resolved.
      #
      # @example
      #   class Show < Base
      #     include PortalSupport
      #
      #     def call(mod_name:, **)
      #       mod_info = portal.get_mod(mod_name)
      #     end
      #   end
      module PortalSupport
        # Lazily resolve Portal from Container
        #
        # @return [Portal] the portal instance
        private def portal = @portal ||= Container[:portal]
      end
    end
  end
end
