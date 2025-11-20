# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Image::Edit do
  let(:portal) { instance_double(Factorix::Portal) }
  let(:command) { Factorix::CLI::Commands::MOD::Image::Edit.new(portal:) }

  before do
    # Suppress stdout
    allow($stdout).to receive(:puts)

    # Mock the Application container
    allow(Factorix::Application).to receive(:[]).with(:portal).and_return(portal)

    # Mock portal.edit_mod_images
    allow(portal).to receive(:edit_mod_images)
  end

  describe "#call" do
    it "edits mod images with multiple IDs" do
      command.call(mod_name: "test-mod", image_ids: %w[abc123 def456 ghi789])

      expect(portal).to have_received(:edit_mod_images).with("test-mod", %w[abc123 def456 ghi789])
      expect($stdout).to have_received(:puts).with("✓ Image list updated successfully!")
      expect($stdout).to have_received(:puts).with("Total images: 3")
    end

    it "edits mod images with single ID" do
      command.call(mod_name: "test-mod", image_ids: %w[abc123])

      expect(portal).to have_received(:edit_mod_images).with("test-mod", %w[abc123])
      expect($stdout).to have_received(:puts).with("Total images: 1")
    end

    it "edits mod images with empty array" do
      command.call(mod_name: "test-mod", image_ids: [])

      expect(portal).to have_received(:edit_mod_images).with("test-mod", [])
      expect($stdout).to have_received(:puts).with("Total images: 0")
    end

    context "when errors occur" do
      before do
        allow(portal).to receive(:edit_mod_images).and_raise(
          Factorix::HTTPClientError.new("400 Bad Request")
        )
      end

      it "raises HTTPClientError" do
        expect {
          command.call(mod_name: "test-mod", image_ids: %w[abc123])
        }.to raise_error(Factorix::HTTPClientError, /400 Bad Request/)
      end
    end
  end
end
