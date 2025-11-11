# frozen_string_literal: true

require "tty-progressbar"

module Factorix
  module Progress
    # Multi progress bar implementation for concurrent file transfers
    #
    # This class manages multiple progress bars for parallel downloads/uploads,
    # using tty-progressbar's Multi feature for thread-safe display.
    class MultiBar
      # Create a new multi progress bar
      #
      # @param title [String] title of the parent progress bar
      # @param output [IO] output stream for the progress bars
      def initialize(title: "Downloads", output: $stderr)
        @multi = TTY::ProgressBar::Multi.new(
          "#{title} [:bar] :percent",
          output:
        )
        @bars = {}
      end

      # Register a new progress bar for a download/upload
      #
      # @param name [String] unique identifier for this bar
      # @param title [String] title to display for this bar
      # @param total_size [Integer] total size in bytes
      # @return [TTY::ProgressBar] the registered progress bar
      def register(name, title:, total_size:)
        bar = @multi.register(
          "#{title} [:bar] :percent :byte/:total_byte",
          total: total_size
        )
        @bars[name] = bar
        bar
      end

      # Update progress for a specific bar
      #
      # @param name [String] identifier of the bar to update
      # @param current_size [Integer] current progress in bytes
      # @return [void]
      def update(name, current_size)
        @bars[name]&.current = current_size
      end

      # Mark a specific bar as finished
      #
      # @param name [String] identifier of the bar to finish
      # @return [void]
      def finish(name)
        @bars[name]&.finish
      end

      # Check if a bar exists
      #
      # @param name [String] identifier to check
      # @return [Boolean] true if bar exists
      def exist?(name)
        @bars.key?(name)
      end
    end
  end
end
