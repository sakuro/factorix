# frozen_string_literal: true

require "dry/events"

RSpec.describe Factorix::Progress::UploadHandler do
  let(:presenter) { instance_double(Factorix::Progress::Presenter) }
  let(:handler) { Factorix::Progress::UploadHandler.new(presenter) }

  describe "#on_upload_started" do
    it "starts the progress presenter with upload-specific format" do
      event = Dry::Events::Event.new("upload.started", total_size: 2000)

      allow(presenter).to receive(:start)

      handler.on_upload_started(event)

      expect(presenter).to have_received(:start).with(
        total: 2000,
        format: "Uploading [:bar] :percent :byte/:total_byte"
      )
    end
  end

  describe "#on_upload_progress" do
    it "updates the progress presenter with current size" do
      event = Dry::Events::Event.new("upload.progress", current_size: 1000, total_size: 2000)

      allow(presenter).to receive(:update)

      handler.on_upload_progress(event)

      expect(presenter).to have_received(:update).with(1000)
    end
  end

  describe "#on_upload_completed" do
    it "finishes the progress presenter" do
      event = Dry::Events::Event.new("upload.completed", total_size: 2000)

      allow(presenter).to receive(:finish)

      handler.on_upload_completed(event)

      expect(presenter).to have_received(:finish)
    end
  end

  describe "full upload lifecycle" do
    it "handles complete upload flow" do
      allow(presenter).to receive(:start)
      allow(presenter).to receive(:update)
      allow(presenter).to receive(:finish)

      handler.on_upload_started(Dry::Events::Event.new("upload.started", total_size: 2000))
      handler.on_upload_progress(Dry::Events::Event.new("upload.progress", current_size: 500, total_size: 2000))
      handler.on_upload_progress(Dry::Events::Event.new("upload.progress", current_size: 1000, total_size: 2000))
      handler.on_upload_progress(Dry::Events::Event.new("upload.progress", current_size: 1500, total_size: 2000))
      handler.on_upload_progress(Dry::Events::Event.new("upload.progress", current_size: 2000, total_size: 2000))
      handler.on_upload_completed(Dry::Events::Event.new("upload.completed", total_size: 2000))

      expect(presenter).to have_received(:start).once
      expect(presenter).to have_received(:update).exactly(4).times
      expect(presenter).to have_received(:finish).once
    end
  end
end
