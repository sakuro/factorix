# frozen_string_literal: true

require "tempfile"
require_relative "../../lib/factorix/mod"
require_relative "../../lib/factorix/mod_list"

RSpec.describe Factorix::ModList do
  let(:base_mod) { Factorix::Mod[name: "base"] }
  let(:enabled_mod) { Factorix::Mod[name: "enabled-mod"] }
  let(:disabled_mod) { Factorix::Mod[name: "disabled-mod"] }
  let(:non_listed_mod) { Factorix::Mod[name: "non-listed-mod"] }

  let(:base_state) { Factorix::ModState[enabled: true] }
  let(:enabled_state) { Factorix::ModState[enabled: true, version: "1.0.0"] }
  let(:disabled_state) { Factorix::ModState[enabled: false] }

  let(:list_path) { Pathname("spec/fixtures/mod-list/list.json") }
  let(:list) { Factorix::ModList.load(from: list_path) }

  describe ".load" do
    it "loads base mod" do
      expect(list).to exist(base_mod)
    end

    it "loads enabled mod" do
      expect(list).to exist(enabled_mod)
    end

    it "loads disabled mod" do
      expect(list).to exist(disabled_mod)
    end

    it "does not load non-listed mod" do
      expect(list).not_to exist(non_listed_mod)
    end

    it "loads version information" do
      expect(list.version(enabled_mod)).to eq("1.0.0")
    end

    it "returns nil for version when not specified for base mod" do
      expect(list.version(base_mod)).to be_nil
    end

    it "returns nil for version when not specified for disabled mod" do
      expect(list.version(disabled_mod)).to be_nil
    end
  end

  describe "#save" do
    it "saves current mod list" do
      Tempfile.open(%w[mod-list- .json]) do |file|
        list.save(to: Pathname(file.path))
        expect(JSON.load_file(file.path)).to eq(JSON.load_file(list_path))
      end
    end
  end

  describe "#each" do
    context "with block" do
      it "iterates through all (mod, state) pairs" do
        expect {|block| list.each(&block) }.to yield_successive_args(
          [base_mod, base_state],
          [enabled_mod, enabled_state],
          [disabled_mod, disabled_state]
        )
      end
    end

    context "without block" do
      let(:enumerator) { list.each }

      it "returns an Enumerator which iterates through all (mod, state) pairs" do
        expect {|block| enumerator.each(&block) }.to yield_successive_args(
          [base_mod, base_state],
          [enabled_mod, enabled_state],
          [disabled_mod, disabled_state]
        )
      end
    end
  end

  describe "#add" do
    context "when adding non-listed MOD" do
      it "adds the MOD" do
        expect { list.add(non_listed_mod) }.to change { list.exist?(non_listed_mod) }.from(false).to(true)
      end

      it "adds MOD as enabled without explicit flag" do
        list.add(non_listed_mod)
        expect(list).to be_enabled(non_listed_mod)
      end

      it "adds MOD as enabled with explicit true flag" do
        list.add(non_listed_mod, enabled: true)
        expect(list).to be_enabled(non_listed_mod)
      end

      it "adds MOD as disabled with explicit false flag" do
        list.add(non_listed_mod, enabled: false)
        expect(list).not_to be_enabled(non_listed_mod)
      end

      it "adds MOD with version" do
        list.add(non_listed_mod, version: "2.0.0")
        expect(list.version(non_listed_mod)).to eq("2.0.0")
      end

      it "adds MOD with nil version by default" do
        list.add(non_listed_mod)
        expect(list.version(non_listed_mod)).to be_nil
      end
    end

    context "when adding already listed MOD" do
      it "enables the MOD without explicit flag" do
        expect { list.add(disabled_mod) }.to change { list.enabled?(disabled_mod) }.from(false).to(true)
      end

      it "enables the MOD with explicit true flag" do
        expect { list.add(disabled_mod, enabled: true) }.to change { list.enabled?(disabled_mod) }.from(false).to(true)
      end

      it "disables the MOD with explicit false flag" do
        expect { list.add(enabled_mod, enabled: false) }.to change { list.enabled?(enabled_mod) }.from(true).to(false)
      end
    end

    context "when adding the base MOD" do
      it "can't add base MOD as disabled" do
        expect { list.add(base_mod, enabled: false) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#remove" do
    context "when removing listed MOD" do
      it "removes the MOD" do
        expect { list.remove(enabled_mod) }.to change { list.exist?(enabled_mod) }.from(true).to(false)
      end
    end

    context "when removing non-listed MOD" do
      it "does nothing" do
        expect { list.remove(non_listed_mod) }.not_to raise_error
      end
    end

    context "when removing the base MOD" do
      it "raises ArgumentError" do
        expect { list.remove(base_mod) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#exist?" do
    it "is truthy for listed MOD" do
      expect(list).to exist(base_mod)
    end

    it "is falsy for non-listed MOD" do
      expect(list).not_to exist(non_listed_mod)
    end
  end

  describe "#enable" do
    it "can enable listed MOD" do
      expect { list.enable(disabled_mod) }.to change { list.enabled?(disabled_mod) }.from(false).to(true)
    end

    it "does nothing to already enabled MOD" do
      expect { list.enable(enabled_mod) }.not_to change { list.enabled?(enabled_mod) }.from(true)
    end

    it "raises ModNotInListError on enabling non-listed MOD" do
      expect { list.enable(non_listed_mod) }.to raise_error(Factorix::ModList::ModNotInListError)
    end

    context "when preserving version information" do
      before do
        # Add a mod with version
        list.add(non_listed_mod, enabled: false, version: "3.0.0")
      end

      it "has the correct version after adding" do
        expect(list.version(non_listed_mod)).to eq("3.0.0")
      end

      it "preserves version information when enabling" do
        # Enable it and check that version is preserved
        list.enable(non_listed_mod)
        expect(list.version(non_listed_mod)).to eq("3.0.0")
      end

      it "is enabled after enabling" do
        list.enable(non_listed_mod)
        expect(list.enabled?(non_listed_mod)).to be true
      end
    end
  end

  describe "#disable" do
    it "can disable listed MOD" do
      expect { list.disable(enabled_mod) }.to change { list.enabled?(enabled_mod) }.from(true).to(false)
    end

    it "does nothing to already disabled MOD" do
      expect { list.disable(disabled_mod) }.not_to change { list.enabled?(disabled_mod) }.from(false)
    end

    it "raises ModNotInListError on disabling non-listed MOD" do
      expect { list.disable(non_listed_mod) }.to raise_error(Factorix::ModList::ModNotInListError)
    end

    it "raises ArgumentError on disabling base MOD" do
      expect { list.disable(base_mod) }.to raise_error(ArgumentError)
    end

    context "when preserving version information for enabled mod" do
      it "has the correct version before disabling" do
        expect(list.version(enabled_mod)).to eq("1.0.0")
      end

      it "preserves version information when disabling" do
        list.disable(enabled_mod)
        expect(list.version(enabled_mod)).to eq("1.0.0")
      end

      it "is disabled after disabling" do
        list.disable(enabled_mod)
        expect(list.enabled?(enabled_mod)).to be false
      end
    end
  end

  describe "#enabled?" do
    it "is truthy for enabled MOD" do
      expect(list).to be_enabled(enabled_mod)
    end

    it "is falsy for disabled MOD" do
      expect(list).not_to be_enabled(disabled_mod)
    end

    it "raises ModNotFoundError for non-listed MOD" do
      expect { list.enabled?(non_listed_mod) }.to raise_error(Factorix::ModNotFoundError)
    end
  end

  describe "#version" do
    it "returns the version for a mod with version" do
      expect(list.version(enabled_mod)).to eq("1.0.0")
    end

    it "returns nil for base mod without version" do
      expect(list.version(base_mod)).to be_nil
    end

    it "returns nil for disabled mod without version" do
      expect(list.version(disabled_mod)).to be_nil
    end

    it "raises ModNotInListError for non-listed MOD" do
      expect { list.version(non_listed_mod) }.to raise_error(Factorix::ModList::ModNotInListError)
    end
  end
end
