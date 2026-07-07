# frozen_string_literal: true

module Factorix
  module Progress
    # Upload progress listener driving a progress presenter
    class UploadHandler
      # Create a new upload handler
      #
      # @param presenter [Presenter, PresenterAdapter] progress presenter to update
      def initialize(presenter) = @presenter = presenter

      # Called when the upload starts
      #
      # @param total [Integer] total size in bytes
      # @return [void]
      def on_started(total:) = @presenter.start(total:, format: "Uploading [:bar] :percent :byte/:total_byte")

      # Called on upload progress
      #
      # @param current [Integer] bytes uploaded so far
      # @return [void]
      def on_progress(current:) = @presenter.update(current)

      # Called when the upload completes
      #
      # @return [void]
      def on_completed = @presenter.finish
    end
  end
end
