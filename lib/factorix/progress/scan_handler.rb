# frozen_string_literal: true

module Factorix
  module Progress
    # Scan event handler for progress presenters
    #
    # This class listens to scan events and updates a progress presenter accordingly.
    class ScanHandler
      # Create a new scan handler
      #
      # @param presenter [Presenter, PresenterAdapter] progress presenter to update
      def initialize(presenter) = @presenter = presenter

      # Handle scan started event
      #
      # @param event [Dry::Events::Event] event with total payload
      # @return [void]
      def on_scan_started(event) = @presenter.start(total: event[:total])

      # Handle scan progress event
      #
      # @param event [Dry::Events::Event] event with current payload
      # @return [void]
      def on_scan_progress(event) = @presenter.update(event[:current])

      # Handle scan completed event
      #
      # @param event [Dry::Events::Event] event with total payload
      # @return [void]
      def on_scan_completed(_event) = @presenter.finish
    end
  end
end
