# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      # Mixin for commands that require the game to be stopped
      #
      # This module provides automatic validation that the game is not running
      # before executing commands that modify MOD installation state or
      # mod-list.json/mod-settings.dat files.
      #
      # Prepend this module in commands that should not run while the game is active
      # (e.g., install, uninstall, enable, disable)
      module RequiresGameStopped
        # Wrapper for command call that checks game state
        # @param options [Hash] command options passed to the original call method
        # @return [void]
        def call(**options)
          # Set @quiet before check_game_stopped because this module is prepended
          # after CommandWrapper (which normally sets @quiet), making it outer in
          # the call chain. If the game is running, the exception escapes before
          # CommandWrapper's rescue block is ever entered.
          @quiet = options[:quiet]
          check_game_stopped
          super
        end

        private def check_game_stopped
          return unless runtime.running?

          message = "Cannot perform this operation while Factorio is running. Please stop the game and try again."
          logger.error("Operation blocked: game is running")
          # CommandWrapper's rescue would normally display this, but it is never
          # reached when the exception is raised here (see call above).
          say "Error: #{message}", prefix: :error
          raise GameRunningError, message
        end
      end
    end
  end
end
