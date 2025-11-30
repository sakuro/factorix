# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      # Display the Factorix manual page
      #
      # This command opens the man page for factorix using the system's man command.
      #
      # @example
      #   $ factorix man
      class Man < Base
        desc "Display the Factorix manual page"

        # Execute the man command
        #
        # @return [void]
        # @raise [CommandNotFoundError] if man command is not available
        def call(**)
          system("command -v man > /dev/null 2>&1")
          raise CommandNotFoundError, "man command is not available on this system" unless $?.success?

          man_page = File.expand_path("../../../../doc/factorix.1", __dir__)
          exec "man", man_page
        end
      end
    end
  end
end
