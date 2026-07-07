# frozen_string_literal: true

RSpec.describe Factorix::Progress::UploadHandler do
  let(:presenter) { instance_double(Factorix::Progress::Presenter) }
  let(:listener) { Factorix::Progress::UploadHandler.new(presenter) }

  describe "#on_started" do
    it "starts the progress presenter with upload-specific format" do
      allow(presenter).to receive(:start)

      listener.on_started(total: 2000)

      expect(presenter).to have_received(:start).with(
        total: 2000,
        format: "Uploading [:bar] :percent :byte/:total_byte"
      )
    end
  end

  describe "#on_progress" do
    it "updates the progress presenter with current size" do
      allow(presenter).to receive(:update)

      listener.on_progress(current: 1000)

      expect(presenter).to have_received(:update).with(1000)
    end
  end

  describe "#on_completed" do
    it "finishes the progress presenter" do
      allow(presenter).to receive(:finish)

      listener.on_completed

      expect(presenter).to have_received(:finish)
    end
  end

  describe "full upload lifecycle" do
    it "handles complete upload flow" do
      allow(presenter).to receive(:start)
      allow(presenter).to receive(:update)
      allow(presenter).to receive(:finish)

      listener.on_started(total: 2000)
      listener.on_progress(current: 500)
      listener.on_progress(current: 1000)
      listener.on_progress(current: 1500)
      listener.on_progress(current: 2000)
      listener.on_completed

      expect(presenter).to have_received(:start).once
      expect(presenter).to have_received(:update).exactly(4).times
      expect(presenter).to have_received(:finish).once
    end
  end
end
