# frozen_string_literal: true

module Factorix
  module Progress
    # Download event handler for progress presenters
    #
    # This class listens to download events and updates a progress presenter accordingly.
    class DownloadHandler
      # Create a new download handler
      #
      # @param presenter [Presenter, PresenterAdapter] progress presenter to update
      def initialize(presenter)
        @presenter = presenter
      end

      # Handle download started event
      #
      # @param event [Dry::Events::Event] event with total_size payload
      # @return [void]
      def on_download_started(event)
        @presenter.start(
          total: event[:total_size],
          format: "Downloading [:bar] :percent :byte/:total_byte"
        )
      end

      # Handle download progress event
      #
      # @param event [Dry::Events::Event] event with current_size payload
      # @return [void]
      def on_download_progress(event)
        @presenter.update(event[:current_size])
      end

      # Handle download completed event
      #
      # @param event [Dry::Events::Event] event with total_size payload
      # @return [void]
      def on_download_completed(_event)
        @presenter.finish
      end

      # Handle cache hit event
      #
      # @param event [Dry::Events::Event] event with url, output, and total_size payload
      # @return [void]
      def on_cache_hit(event)
        total_size = event.payload.fetch(:total_size, 1)

        # Start and complete immediately for cache hits
        @presenter.start(
          total: total_size,
          format: "[:bar] :percent :byte/:total_byte"
        )
        @presenter.update(total_size)
        @presenter.finish
      end
    end
  end
end
