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

  describe "#increase_total" do
    it "increases the total count dynamically" do
      presenter = nil
      capture_stderr do
        presenter = Factorix::Progress::Presenter.new(title: "Fetching")

        # Start with initial total
        presenter.start(total: 3)

        # Verify initial total
        expect(presenter.instance_variable_get(:@tty_bar).total).to eq(3)

        # Increase total by 2
        presenter.increase_total(2)

        # Verify total is increased
        expect(presenter.instance_variable_get(:@tty_bar).total).to eq(5)

        # Finish
        presenter.finish
      end
    end

    it "handles nil total gracefully" do
      presenter = nil
      capture_stderr do
        presenter = Factorix::Progress::Presenter.new(title: "Processing")

        # Start without total
        presenter.start(total: nil)

        # Increase total (should set to increment value)
        presenter.increase_total(5)

        # Verify total is set
        expect(presenter.instance_variable_get(:@tty_bar).total).to eq(5)

        # Finish
        presenter.finish
      end
    end
  end
end
