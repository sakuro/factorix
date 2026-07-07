# frozen_string_literal: true

RSpec.describe Factorix::Progress::DownloadHandler do
  let(:presenter) { instance_double(Factorix::Progress::Presenter) }
  let(:listener) { Factorix::Progress::DownloadHandler.new(presenter) }

  describe "#on_started" do
    it "starts the progress presenter with the total size" do
      allow(presenter).to receive(:start)

      listener.on_started(total: 1000)

      expect(presenter).to have_received(:start).with(total: 1000)
    end
  end

  describe "#on_progress" do
    it "updates the progress presenter with current size" do
      allow(presenter).to receive(:update)

      listener.on_progress(current: 500)

      expect(presenter).to have_received(:update).with(500)
    end
  end

  describe "#on_completed" do
    it "finishes the progress presenter" do
      allow(presenter).to receive(:finish)

      listener.on_completed

      expect(presenter).to have_received(:finish)
    end
  end

  describe "full download lifecycle" do
    it "handles complete download flow" do
      allow(presenter).to receive(:start)
      allow(presenter).to receive(:update)
      allow(presenter).to receive(:finish)

      listener.on_started(total: 1000)
      listener.on_progress(current: 250)
      listener.on_progress(current: 500)
      listener.on_progress(current: 750)
      listener.on_progress(current: 1000)
      listener.on_completed

      expect(presenter).to have_received(:start).once
      expect(presenter).to have_received(:update).exactly(4).times
      expect(presenter).to have_received(:finish).once
    end
  end

  describe "#on_cache_hit" do
    it "shows cached status with file size" do
      allow(presenter).to receive(:start)
      allow(presenter).to receive(:update)
      allow(presenter).to receive(:finish)

      listener.on_cache_hit(total: 1024)

      expect(presenter).to have_received(:start).with(total: 1024)
      expect(presenter).to have_received(:update).with(1024)
      expect(presenter).to have_received(:finish)
    end

    it "uses fallback size when total is nil" do
      allow(presenter).to receive(:start)
      allow(presenter).to receive(:update)
      allow(presenter).to receive(:finish)

      listener.on_cache_hit(total: nil)

      expect(presenter).to have_received(:start).with(total: 1)
      expect(presenter).to have_received(:update).with(1)
      expect(presenter).to have_received(:finish)
    end
  end
end
