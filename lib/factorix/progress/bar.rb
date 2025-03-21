# frozen_string_literal: true

require "ruby-progressbar"

module Factorix
  module Progress
    # Progress bar implementation using ruby-progressbar
    class Bar
      # Create a new progress bar
      # @param title [String] title of the progress bar
      def initialize(title: "Downloading")
        @bar = ProgressBar.create(
          title: title,
          format: "%t: |%B| %p%% %e",
          output: $stderr
        )
      end

      # Called when the content length is known
      # @return [Proc] callback for content length
      def content_length_proc
        ->(size) { bar.total = size if size }
      end

      # Called when a chunk is downloaded
      # @return [Proc] callback for progress updates
      def progress_proc
        ->(size) { bar.progress = size }
      end

      # @return [ProgressBar] the progress bar instance
      private attr_reader :bar
    end
  end
end
