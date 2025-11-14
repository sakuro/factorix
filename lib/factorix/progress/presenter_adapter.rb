# frozen_string_literal: true

module Factorix
  module Progress
    # Adapter to make TTY::ProgressBar compatible with Presenter interface
    #
    # This adapter wraps a TTY::ProgressBar instance and provides the same
    # interface as Progress::Presenter, allowing them to be used interchangeably.
    class PresenterAdapter
      # Create a new presenter adapter
      #
      # @param tty_bar [TTY::ProgressBar] the progress bar to adapt
      def initialize(tty_bar)
        @tty_bar = tty_bar
        @started = false
      end

      # Start the progress presentation
      #
      # @param total [Integer] total size/count for progress tracking
      # @param format [String, nil] format string (ignored, already set in TTY::ProgressBar)
      # @return [void]
      def start(total:, format: nil)
        _ = format # Acknowledge unused parameter
        @tty_bar.update(total:) if total
        @tty_bar.start unless @started
        @started = true
      end

      # Update the progress to a specific value
      #
      # @param current [Integer] current progress value
      # @return [void]
      def update(current)
        @tty_bar.current = current
      end

      # Mark the progress as finished
      #
      # @return [void]
      def finish
        @tty_bar.finish
      end
    end
  end
end
