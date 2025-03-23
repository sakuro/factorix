# frozen_string_literal: true

require "ruby-progressbar"

module Factorix
  module Progress
    # Progress bar implementation for file downloads
    # Provides a simple interface to display download progress using ruby-progressbar
    class Bar
      # Create a new progress bar for file downloads
      #
      # @param title [String] title of the progress bar
      # @return [void]
      def initialize(title: "Downloading")
        @bar = ProgressBar.create(
          title:,
          format: "%t: |%B| %p%% %e",
          output: $stderr
        )
      end

      # Returns a callback for setting the total content length
      # This callback is used by OpenURI to set the total size of the file being downloaded
      #
      # @return [Proc] callback that accepts the content length as an argument
      def content_length_proc
        ->(size) { bar.total = size if size }
      end

      # Returns a callback for updating the progress
      # This callback is used by OpenURI to update the progress as chunks are downloaded
      #
      # @return [Proc] callback that accepts the current size as an argument
      def progress_proc
        ->(size) { bar.progress = size }
      end

      # The underlying progress bar instance
      # @return [ProgressBar] the progress bar instance
      private attr_reader :bar
    end
  end
end
