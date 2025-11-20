# frozen_string_literal: true

require "spec_helper"

RSpec.describe Factorix::SaveFile do
  describe ".load" do
    let(:save_file_path) { Pathname("spec/fixtures/test-save.zip") }

    context "with a valid save file" do
      subject(:save_data) { Factorix::SaveFile.load(save_file_path) }

      it "returns SaveFile" do
        expect(save_data).to be_a(Factorix::SaveFile)
      end

      it "extracts game version" do
        expect(save_data.version).to be_a(Factorix::Types::GameVersion)
        expect(save_data.version.to_s).to eq("2.0.72")
      end

      it "extracts MOD list" do
        expect(save_data.mods).to be_a(Hash)
        expect(save_data.mods).not_to be_empty
      end

      it "includes base MOD in the list" do
        expect(save_data.mods).to have_key("base")
        expect(save_data.mods["base"]).to be_a(Factorix::MODState)
      end

      it "marks all MODs as enabled" do
        save_data.mods.each_value do |mod_state|
          expect(mod_state.enabled?).to be true
        end
      end

      it "includes MOD versions" do
        base_mod = save_data.mods["base"]
        expect(base_mod.version).to be_a(Factorix::Types::MODVersion)
        expect(base_mod.version.to_s).to eq("2.0.72")
      end

      it "extracts startup settings" do
        expect(save_data.startup_settings).to be_a(Factorix::MODSettings::Section)
        expect(save_data.startup_settings.name).to eq("startup")
      end

      it "includes startup setting values" do
        # The test save file has some startup settings
        expect(save_data.startup_settings).not_to be_empty
      end
    end
  end
end
