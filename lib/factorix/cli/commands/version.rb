# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      # Display Factorix version
      #
      # This command outputs the current version of the Factorix gem.
      #
      # @example
      #   $ factorix version
      #   0.1.0
      class Version < Base
        desc "Display Factorix version"

        # Execute the version command
        #
        # Outputs the current version of the Factorix gem to stdout.
        #
        # @return [void]
        def call(**) = out.puts VERSION
      end
    end
  end
end
