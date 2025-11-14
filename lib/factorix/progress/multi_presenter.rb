# frozen_string_literal: true

require "tty-progressbar"

module Factorix
  module Progress
    # Multi-progress presenter implementation
    #
    # This class provides a multi-progress presentation interface using tty-progressbar.
    # It manages multiple progress bars that can be updated concurrently.
    class MultiPresenter
      # Create a new multi-progress presenter
      #
      # @param title [String] title of the multi-progress presenter
      # @param output [IO] output stream for the progress presenter
      def initialize(title: "Progress", output: $stderr)
        @title = title
        @output = output
        @multi = TTY::ProgressBar::Multi.new(
          @title,
          output: @output,
          style: {
            top: "",
            middle: "",
            bottom: ""
          }
        )
        @presenters = {}
        @mutex = Mutex.new
      end

      # Register a new progress presenter
      #
      # @param name [String, Symbol] unique identifier for this progress presenter
      # @param title [String] title for this specific progress presenter
      # @return [PresenterAdapter] adapter wrapping the TTY::ProgressBar
      def register(name, title:)
        @mutex.synchronize do
          tty_bar = @multi.register("#{title} [:bar] :percent :byte/:total_byte")
          adapter = PresenterAdapter.new(tty_bar, @mutex)
          @presenters[name] = adapter
          adapter
        end
      end

      # Get a registered presenter by name
      #
      # @param name [String, Symbol] the identifier used during registration
      # @return [PresenterAdapter, nil] the presenter adapter or nil if not found
      def [](name)
        @presenters[name]
      end
    end
  end
end
