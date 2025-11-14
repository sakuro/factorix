# frozen_string_literal: true

require "dry/events"

RSpec.describe Factorix::Progress::DownloadHandler do
  let(:presenter) { instance_double(Factorix::Progress::Presenter) }
  let(:handler) { Factorix::Progress::DownloadHandler.new(presenter) }

  describe "#on_download_started" do
    it "starts the progress presenter with download-specific format" do
      event = Dry::Events::Event.new("download.started", total_size: 1000)

      allow(presenter).to receive(:start)

      handler.on_download_started(event)

      expect(presenter).to have_received(:start).with(
        total: 1000,
        format: "Downloading [:bar] :percent :byte/:total_byte"
      )
    end
  end

  describe "#on_download_progress" do
    it "updates the progress presenter with current size" do
      event = Dry::Events::Event.new("download.progress", current_size: 500, total_size: 1000)

      allow(presenter).to receive(:update)

      handler.on_download_progress(event)

      expect(presenter).to have_received(:update).with(500)
    end
  end

  describe "#on_download_completed" do
    it "finishes the progress presenter" do
      event = Dry::Events::Event.new("download.completed", total_size: 1000)

      allow(presenter).to receive(:finish)

      handler.on_download_completed(event)

      expect(presenter).to have_received(:finish)
    end
  end

  describe "full download lifecycle" do
    it "handles complete download flow" do
      allow(presenter).to receive(:start)
      allow(presenter).to receive(:update)
      allow(presenter).to receive(:finish)

      handler.on_download_started(Dry::Events::Event.new("download.started", total_size: 1000))
      handler.on_download_progress(Dry::Events::Event.new("download.progress", current_size: 250, total_size: 1000))
      handler.on_download_progress(Dry::Events::Event.new("download.progress", current_size: 500, total_size: 1000))
      handler.on_download_progress(Dry::Events::Event.new("download.progress", current_size: 750, total_size: 1000))
      handler.on_download_progress(Dry::Events::Event.new("download.progress", current_size: 1000, total_size: 1000))
      handler.on_download_completed(Dry::Events::Event.new("download.completed", total_size: 1000))

      expect(presenter).to have_received(:start).once
      expect(presenter).to have_received(:update).exactly(4).times
      expect(presenter).to have_received(:finish).once
    end
  end

  describe "#on_cache_hit" do
    it "shows cached status with file size" do
      event = Dry::Events::Event.new(
        "cache.hit",
        url: "https://example.com/file.zip",
        output: "/tmp/file.zip",
        total_size: 1024
      )

      allow(presenter).to receive(:start)
      allow(presenter).to receive(:update)
      allow(presenter).to receive(:finish)

      handler.on_cache_hit(event)

      expect(presenter).to have_received(:start).with(
        total: 1024,
        format: "[:bar] :percent :byte/:total_byte"
      )
      expect(presenter).to have_received(:update).with(1024)
      expect(presenter).to have_received(:finish)
    end

    it "uses fallback size when total_size is nil" do
      event = Dry::Events::Event.new(
        "cache.hit",
        url: "https://example.com/file.zip",
        output: "/tmp/file.zip"
      )

      allow(presenter).to receive(:start)
      allow(presenter).to receive(:update)
      allow(presenter).to receive(:finish)

      handler.on_cache_hit(event)

      expect(presenter).to have_received(:start).with(
        total: 1,
        format: "[:bar] :percent :byte/:total_byte"
      )
      expect(presenter).to have_received(:update).with(1)
      expect(presenter).to have_received(:finish)
    end
  end
end
