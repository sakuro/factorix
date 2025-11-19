# frozen_string_literal: true

RSpec.describe Factorix::Progress::Presenter do
  describe "determinate progress" do
    it "creates progress bar with determinate format and updates with specific current value" do
      presenter = nil
      capture_stderr do
        presenter = Factorix::Progress::Presenter.new(title: "Download")

        # Start with total (determinate mode)
        presenter.start(total: 100)

        # Verify progress bar is created
        expect(presenter.instance_variable_get(:@tty_bar)).not_to be_nil

        # Update with specific current value (not advance)
        presenter.update(50)

        # Verify current value is set
        expect(presenter.instance_variable_get(:@tty_bar).current).to eq(50)

        # Finish
        presenter.finish
      end

      # Verify progress bar is marked as complete
      expect(presenter.instance_variable_get(:@tty_bar).complete?).to be true

      # Test exercises:
      # - Line 32: determinate format "#{@title} [:bar] :percent :current/:total"
      # - Line 49: @tty_bar&.current = current
    end
  end

  describe "indeterminate progress" do
    it "creates progress bar with indeterminate format and advances without specific value" do
      presenter = nil
      capture_stderr do
        presenter = Factorix::Progress::Presenter.new(title: "Processing")

        # Start without total (indeterminate mode)
        presenter.start(total: nil)

        # Verify progress bar is created
        expect(presenter.instance_variable_get(:@tty_bar)).not_to be_nil

        # Update without argument (advance)
        presenter.update

        # Verify current value is advanced
        expect(presenter.instance_variable_get(:@tty_bar).current).to eq(1)

        # Finish
        presenter.finish
      end

      # Verify progress bar is marked as complete
      expect(presenter.instance_variable_get(:@tty_bar).complete?).to be true

      # Test exercises:
      # - Line 29: indeterminate format "#{@title} [:bar] :current"
      # - Line 52: @tty_bar&.advance
    end
  end
end
