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
      # @param mutex [Mutex] mutex for thread-safe operations
      def initialize(tty_bar, mutex)
        @tty_bar = tty_bar
        @mutex = mutex
        @started = false
      end

      # Start the progress presentation
      #
      # @param total [Integer] total size/count for progress tracking
      # @param format [String, nil] format string (ignored, already set in TTY::ProgressBar)
      # @return [void]
      def start(total:, format: nil)
        _ = format # Acknowledge unused parameter
        @mutex.synchronize do
          @tty_bar.update(total:) if total
          @tty_bar.start unless @started
          @started = true
        end
      end

      # Update the progress to a specific value
      #
      # @param current [Integer] current progress value
      # @return [void]
      def update(current)
        @mutex.synchronize { @tty_bar.current = current }
      end

      # Mark the progress as finished
      #
      # @return [void]
      def finish
        @mutex.synchronize { @tty_bar.finish }
      end
    end
  end
end
