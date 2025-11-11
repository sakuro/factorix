# frozen_string_literal: true

require "tty-progressbar"

module Factorix
  module Progress
    # Progress bar implementation for file transfers
    #
    # This class acts as an event listener for Transfer events,
    # displaying download/upload progress using tty-progressbar.
    class Bar
      # Create a new progress bar for file transfers
      #
      # @param title [String] title of the progress bar
      # @param output [IO] output stream for the progress bar
      def initialize(title: "Progress", output: $stderr)
        @title = title
        @output = output
        @bar = nil
      end

      # Handle download started event
      #
      # @param event [Dry::Events::Event] event with total_size payload
      # @return [void]
      def on_download_started(event)
        create_bar("Downloading", event[:total_size])
      end

      # Handle download progress event
      #
      # @param event [Dry::Events::Event] event with current_size payload
      # @return [void]
      def on_download_progress(event)
        @bar&.current = event[:current_size]
      end

      # Handle download completed event
      #
      # @param event [Dry::Events::Event] event with total_size payload
      # @return [void]
      def on_download_completed(_event)
        @bar&.finish
      end

      # Handle upload started event
      #
      # @param event [Dry::Events::Event] event with total_size payload
      # @return [void]
      def on_upload_started(event)
        create_bar("Uploading", event[:total_size])
      end

      # Handle upload progress event
      #
      # @param event [Dry::Events::Event] event with current_size payload
      # @return [void]
      def on_upload_progress(event)
        @bar&.current = event[:current_size]
      end

      # Handle upload completed event
      #
      # @param event [Dry::Events::Event] event with total_size payload
      # @return [void]
      def on_upload_completed(_event)
        @bar&.finish
      end

      private def create_bar(title, total_size)
        @bar = TTY::ProgressBar.new(
          "#{title} [:bar] :percent :byte/:total_byte",
          total: total_size,
          output: @output,
          frequency: 1, # Always update (important for testing with StringIO)
          force: true   # Force output even when not a TTY
        )
      end
    end
  end
end
