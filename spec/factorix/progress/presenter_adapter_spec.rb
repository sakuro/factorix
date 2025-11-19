# frozen_string_literal: true

require "tty-progressbar"

RSpec.describe Factorix::Progress::PresenterAdapter do
  let(:tty_bar) { instance_spy(TTY::ProgressBar) }
  let(:mutex) { Mutex.new }
  let(:adapter) { Factorix::Progress::PresenterAdapter.new(tty_bar, mutex) }

  describe "#start" do
    context "with total provided" do
      it "updates total and starts the progress bar" do
        adapter.start(total: 100)

        expect(tty_bar).to have_received(:update).with(total: 100)
        expect(tty_bar).to have_received(:start)
      end

      it "marks the adapter as started" do
        adapter.start(total: 100)

        # Second call should not call start again
        adapter.start(total: 100)
        expect(tty_bar).to have_received(:start).once
      end
    end

    context "without total" do
      it "starts the progress bar without updating total" do
        adapter.start(total: nil)

        expect(tty_bar).not_to have_received(:update)
        expect(tty_bar).to have_received(:start)
      end
    end

    it "ignores format parameter" do
      expect { adapter.start(total: nil, format: "custom format") }.not_to raise_error
    end
  end

  describe "#update" do
    it "updates the current value of the progress bar" do
      adapter.update(50)

      expect(tty_bar).to have_received(:current=).with(50)
    end
  end

  describe "#finish" do
    it "finishes the progress bar" do
      adapter.finish

      expect(tty_bar).to have_received(:finish)
    end
  end
end
