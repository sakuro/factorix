# frozen_string_literal: true

require "tty-progressbar"

module Factorix
  module Progress
    # Progress presenter implementation
    #
    # This class provides a simple progress presentation interface using tty-progressbar.
    class Presenter
      # Create a new progress presenter
      #
      # @param title [String] title of the progress presenter
      # @param output [IO] output stream for the progress presenter
      def initialize(title: "Progress", output: $stderr)
        @title = title
        @output = output
        @tty_bar = nil
      end

      # Start the progress presentation with a specific total
      #
      # @param total [Integer] total size/count for progress tracking
      # @param format [String] progress presenter format string (default: generic format)
      # @return [void]
      def start(total: nil, format: nil)
        format ||= total.nil? ? "#{@title} [:bar] :current" : "#{@title} [:bar] :percent :current/:total"
        @tty_bar = TTY::ProgressBar.new(
          format,
          total:,
          output: @output,
          frequency: 1, # Always update (important for testing with StringIO)
          force: true   # Force output even when not a TTY
        )
      end

      # Update the progress presenter to a specific value
      #
      # @param current [Integer] current progress value
      # @return [void]
      def update(current=nil)
        if current
          @tty_bar&.current = current
        else
          # For indeterminate progress, just advance
          @tty_bar&.advance
        end
      end

      # Increase the total count dynamically
      #
      # @param increment [Integer] amount to add to current total
      # @return [void]
      def increase_total(increment)
        return unless @tty_bar

        current_total = @tty_bar.total || 0
        @tty_bar.update(total: current_total + increment)
      end

      # Mark the progress presenter as finished
      #
      # @return [void]
      def finish = @tty_bar&.finish
    end
  end
end
