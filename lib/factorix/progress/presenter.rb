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
      # @param force [Boolean, nil] render even when output is not a TTY
      #   (nil defers to output.tty?, so piped/redirected output stays clean)
      def initialize(title: "Progress", output: $stderr, force: nil)
        @title = title
        @output = output
        @force = force.nil? ? output.tty? : force
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
          force: @force
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
