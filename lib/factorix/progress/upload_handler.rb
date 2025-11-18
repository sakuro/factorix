# frozen_string_literal: true

module Factorix
  module Progress
    # Upload event handler for progress presenters
    #
    # This class listens to upload events and updates a progress presenter accordingly.
    class UploadHandler
      # Create a new upload handler
      #
      # @param presenter [Presenter, PresenterAdapter] progress presenter to update
      def initialize(presenter) = @presenter = presenter

      # Handle upload started event
      #
      # @param event [Dry::Events::Event] event with total_size payload
      # @return [void]
      def on_upload_started(event)
        @presenter.start(
          total: event[:total_size],
          format: "Uploading [:bar] :percent :byte/:total_byte"
        )
      end

      # Handle upload progress event
      #
      # @param event [Dry::Events::Event] event with current_size payload
      # @return [void]
      def on_upload_progress(event) = @presenter.update(event[:current_size])

      # Handle upload completed event
      #
      # @param event [Dry::Events::Event] event with total_size payload
      # @return [void]
      def on_upload_completed(_event) = @presenter.finish
    end
  end
end
