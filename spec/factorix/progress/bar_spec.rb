# frozen_string_literal: true

RSpec.describe Factorix::Progress::Bar do
  let(:output) { StringIO.new }
  let(:progress_bar) { Factorix::Progress::Bar.new(title: "Test", output:) }

  describe "download event handling" do
    it "handles download.started event" do
      event = Dry::Events::Event.new("download.started", total_size: 1000)

      expect { progress_bar.on_download_started(event) }.not_to raise_error
    end

    it "handles download.progress event" do
      # Start the progress bar first
      progress_bar.on_download_started(Dry::Events::Event.new("download.started", total_size: 1000))

      event = Dry::Events::Event.new("download.progress", current_size: 500, total_size: 1000)

      expect { progress_bar.on_download_progress(event) }.not_to raise_error
    end

    it "handles download.completed event" do
      # Start the progress bar first
      progress_bar.on_download_started(Dry::Events::Event.new("download.started", total_size: 1000))

      event = Dry::Events::Event.new("download.completed", total_size: 1000)

      expect { progress_bar.on_download_completed(event) }.not_to raise_error
    end
  end

  describe "upload event handling" do
    it "handles upload.started event" do
      event = Dry::Events::Event.new("upload.started", total_size: 2000)

      expect { progress_bar.on_upload_started(event) }.not_to raise_error
    end

    it "handles upload.progress event" do
      # Start the progress bar first
      progress_bar.on_upload_started(Dry::Events::Event.new("upload.started", total_size: 2000))

      event = Dry::Events::Event.new("upload.progress", current_size: 1000, total_size: 2000)

      expect { progress_bar.on_upload_progress(event) }.not_to raise_error
    end

    it "handles upload.completed event" do
      # Start the progress bar first
      progress_bar.on_upload_started(Dry::Events::Event.new("upload.started", total_size: 2000))

      event = Dry::Events::Event.new("upload.completed", total_size: 2000)

      expect { progress_bar.on_upload_completed(event) }.not_to raise_error
    end
  end

  describe "progress bar output" do
    it "outputs to the specified stream" do
      progress_bar.on_download_started(Dry::Events::Event.new("download.started", total_size: 100))
      progress_bar.on_download_progress(Dry::Events::Event.new("download.progress", current_size: 50, total_size: 100))
      progress_bar.on_download_completed(Dry::Events::Event.new("download.completed", total_size: 100))

      # Progress bar should have written something to the output
      expect(output.string).not_to be_empty
    end
  end
end
