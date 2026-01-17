# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Image::Edit do
  include_context "with suppressed output"

  let(:portal) { instance_double(Factorix::Portal) }
  let(:command) { Factorix::CLI::Commands::MOD::Image::Edit.new(portal:) }

  before do
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:portal).and_return(portal)
    allow(portal).to receive(:edit_mod_images)
  end

  describe "#call" do
    it "edits MOD images with multiple IDs" do
      command.call(mod_name: "test-mod", image_ids: %w[abc123 def456 ghi789])

      expect(portal).to have_received(:edit_mod_images).with("test-mod", %w[abc123 def456 ghi789])
    end

    it "edits MOD images with single ID" do
      command.call(mod_name: "test-mod", image_ids: %w[abc123])

      expect(portal).to have_received(:edit_mod_images).with("test-mod", %w[abc123])
    end

    it "edits MOD images with empty array" do
      command.call(mod_name: "test-mod", image_ids: [])

      expect(portal).to have_received(:edit_mod_images).with("test-mod", [])
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
