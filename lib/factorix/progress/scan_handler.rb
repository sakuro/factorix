# frozen_string_literal: true

module Factorix
  module Progress
    # Scan progress listener driving a progress presenter
    class ScanHandler
      # Create a new scan handler
      #
      # @param presenter [Presenter, PresenterAdapter] progress presenter to update
      def initialize(presenter) = @presenter = presenter

      # Called when the scan starts
      #
      # @param total [Integer] total number of paths to scan
      # @return [void]
      def on_started(total:) = @presenter.start(total:)

      # Called on scan progress
      #
      # @param current [Integer] number of paths scanned so far
      # @return [void]
      def on_progress(current:) = @presenter.update(current)

      # Called when the scan completes
      #
      # @return [void]
      def on_completed = @presenter.finish
    end
  end
end
