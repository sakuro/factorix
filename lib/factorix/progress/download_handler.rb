# frozen_string_literal: true

module Factorix
  module Progress
    # Download progress listener driving a progress presenter
    class DownloadHandler
      # Create a new download handler
      #
      # @param presenter [Presenter, PresenterAdapter] progress presenter to update
      def initialize(presenter) = @presenter = presenter

      # Called when the download starts
      #
      # @param total [Integer, nil] total size in bytes (nil if unknown)
      # @return [void]
      def on_started(total:) = @presenter.start(total:)

      # Called on download progress
      #
      # @param current [Integer] bytes downloaded so far
      # @return [void]
      def on_progress(current:) = @presenter.update(current)

      # Called when the download completes
      #
      # @return [void]
      def on_completed = @presenter.finish

      # Called when the file is served from cache instead of downloaded
      #
      # @param total [Integer, nil] cached file size in bytes
      # @return [void]
      def on_cache_hit(total:)
        size = total || 1

        # Start and complete immediately for cache hits
        @presenter.start(total: size)
        @presenter.update(size)
        @presenter.finish
      end
    end
  end
end
