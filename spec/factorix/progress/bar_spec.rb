# frozen_string_literal: true

require "ruby-progressbar"

RSpec.describe Factorix::Progress::Bar do
  subject(:progress) { Factorix::Progress::Bar.new(title:) }

  let(:title) { "Test Download" }
  let(:progress_bar) { instance_double(ProgressBar::Base, total: 0, progress: 0) }

  before do
    allow(ProgressBar).to receive(:create).with(
      title:,
      format: "%t: |%B| %p%% %e",
      output: $stderr
    ).and_return(progress_bar)
  end

  describe "#initialize" do
    it "creates a progress bar with the given title" do
      progress
      expect(ProgressBar).to have_received(:create).with(
        title:,
        format: "%t: |%B| %p%% %e",
        output: $stderr
      )
    end
  end

  describe "#content_length_proc" do
    subject(:content_length_proc) { progress.content_length_proc }

    before do
      allow(progress_bar).to receive(:total=)
    end

    context "when size is provided" do
      it "sets the total size of the progress bar" do
        content_length_proc.call(1000)
        expect(progress_bar).to have_received(:total=).with(1000)
      end
    end

    context "when size is nil" do
      it "does not set the total size" do
        content_length_proc.call(nil)
        expect(progress_bar).not_to have_received(:total=)
      end
    end
  end

  describe "#progress_proc" do
    subject(:progress_proc) { progress.progress_proc }

    before do
      allow(progress_bar).to receive(:progress=)
    end

    it "updates the progress" do
      progress_proc.call(500)
      expect(progress_bar).to have_received(:progress=).with(500)
    end
  end
end
