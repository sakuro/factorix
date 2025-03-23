# frozen_string_literal: true

require_relative "../../lib/factorix/mod_context"

RSpec.describe Factorix::ModContext do
  let(:base_mod) { Factorix::Mod[name: "base"] }
  let(:enabled_mod) { Factorix::Mod[name: "mod1"] }
  let(:disabled_mod) { Factorix::Mod[name: "mod2"] }
  let(:another_enabled_mod) { Factorix::Mod[name: "mod3"] }

  let(:mod_list) { instance_double(Factorix::ModList) }
  let(:mod_context) { Factorix::ModContext.new(mod_list) }

  describe "#with_only_enabled" do
    before do
      # Setup the mod_list double to return the MODs
      allow(mod_list).to receive(:each_mod) do |&block|
        if block
          block.call(base_mod)
          block.call(enabled_mod)
          block.call(disabled_mod)
          block.call(another_enabled_mod)
          mod_list
        else
          # Return an Enumerator when no block is given
          [base_mod, enabled_mod, disabled_mod, another_enabled_mod].to_enum
        end
      end

      # Setup initial enabled states
      allow(mod_list).to receive(:enabled?).with(base_mod).and_return(true)
      allow(mod_list).to receive(:enabled?).with(enabled_mod).and_return(true)
      allow(mod_list).to receive(:enabled?).with(disabled_mod).and_return(false)
      allow(mod_list).to receive(:enabled?).with(another_enabled_mod).and_return(true)

      # Allow enable/disable calls
      allow(mod_list).to receive(:enable)
      allow(mod_list).to receive(:disable)
      allow(mod_list).to receive(:save)
    end

    context "when enabling a specific MOD" do
      before do
        # Call with_only_enabled with disabled_mod
        mod_context.with_only_enabled("mod2") { "test block" }
      end

      it "does not disable the base MOD" do
        expect(mod_list).not_to have_received(:disable).with(base_mod)
      end

      it "disables the enabled MOD" do
        expect(mod_list).to have_received(:disable).with(enabled_mod)
      end

      it "enables the disabled MOD" do
        expect(mod_list).to have_received(:enable).with(disabled_mod)
      end

      it "disables the other enabled MOD" do
        expect(mod_list).to have_received(:disable).with(another_enabled_mod)
      end
    end

    context "when restoring original MOD states" do
      before do
        # Call with_only_enabled with an empty list (only base MOD enabled)
        mod_context.with_only_enabled { "test block" }
      end

      it "re-enables the originally enabled MOD" do
        expect(mod_list).to have_received(:enable).with(enabled_mod).at_least(:once)
      end

      it "keeps the originally disabled MOD disabled" do
        expect(mod_list).to have_received(:disable).with(disabled_mod).at_least(:once)
      end

      it "re-enables the other originally enabled MOD" do
        expect(mod_list).to have_received(:enable).with(another_enabled_mod).at_least(:once)
      end
    end

    context "when the block raises an error" do
      before do
        # Call with_only_enabled with an empty list and a block that raises an error

        mod_context.with_only_enabled { raise RuntimeError, "Test error" }
      rescue RuntimeError
        # Expected error, continue with the test
      end

      it "re-enables the originally enabled MOD" do
        expect(mod_list).to have_received(:enable).with(enabled_mod).at_least(:once)
      end

      it "keeps the originally disabled MOD disabled" do
        expect(mod_list).to have_received(:disable).with(disabled_mod).at_least(:once)
      end

      it "re-enables the other originally enabled MOD" do
        expect(mod_list).to have_received(:enable).with(another_enabled_mod).at_least(:once)
      end
    end

    it "saves the MOD list after enabling/disabling and after restoring" do
      # Call with_only_enabled
      mod_context.with_only_enabled("mod2") { "test block" }

      # Verify save was called twice
      expect(mod_list).to have_received(:save).twice
    end
  end
end
