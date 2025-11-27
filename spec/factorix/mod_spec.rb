# frozen_string_literal: true

RSpec.describe Factorix::MOD do
  describe "#initialize" do
    it "creates a MOD with a name" do
      mod = Factorix::MOD[name: "example-mod"]
      expect(mod.name).to eq("example-mod")
    end
  end

  describe "#base?" do
    it "returns true for the base MOD" do
      mod = Factorix::MOD[name: "base"]
      expect(mod.base?).to be(true)
    end

    it "returns false for non-base MODs" do
      mod = Factorix::MOD[name: "example-mod"]
      expect(mod.base?).to be(false)
    end

    it "is case-sensitive" do
      aggregate_failures "case-sensitive base check" do
        expect(Factorix::MOD[name: "BASE"].base?).to be(false)
        expect(Factorix::MOD[name: "Base"].base?).to be(false)
      end
    end
  end

  describe "#expansion?" do
    it "returns true for space-age" do
      mod = Factorix::MOD[name: "space-age"]
      expect(mod.expansion?).to be(true)
    end

    it "returns true for quality" do
      mod = Factorix::MOD[name: "quality"]
      expect(mod.expansion?).to be(true)
    end

    it "returns true for elevated-rails" do
      mod = Factorix::MOD[name: "elevated-rails"]
      expect(mod.expansion?).to be(true)
    end

    it "returns false for base MOD" do
      mod = Factorix::MOD[name: "base"]
      expect(mod.expansion?).to be(false)
    end

    it "returns false for other MODs" do
      mod = Factorix::MOD[name: "example-mod"]
      expect(mod.expansion?).to be(false)
    end

    it "is case-sensitive" do
      mod = Factorix::MOD[name: "Space-Age"]
      expect(mod.expansion?).to be(false)
    end
  end

  describe "#to_s" do
    it "returns the name of the MOD" do
      mod = Factorix::MOD[name: "example-mod"]
      expect(mod.to_s).to eq("example-mod")
    end
  end

  describe "#<=>" do
    let(:base_mod) { Factorix::MOD[name: "base"] }
    let(:mod_a) { Factorix::MOD[name: "a-mod"] }
    let(:mod_b) { Factorix::MOD[name: "b-mod"] }
    let(:mod_a_dup) { Factorix::MOD[name: "a-mod"] }

    it "considers equal MODs as equal" do
      expect(mod_a <=> mod_a_dup).to eq(0)
    end

    it "considers base MOD less than any other MOD" do
      expect(base_mod <=> mod_a).to eq(-1)
      expect(base_mod <=> mod_b).to eq(-1)
    end

    it "considers any MOD greater than base MOD" do
      expect(mod_a <=> base_mod).to eq(1)
      expect(mod_b <=> base_mod).to eq(1)
    end

    it "considers two base MODs as equal" do
      other_base = Factorix::MOD[name: "base"]
      expect(base_mod <=> other_base).to eq(0)
    end

    it "compares non-base MODs alphabetically" do
      expect(mod_a <=> mod_b).to eq(-1)
      expect(mod_b <=> mod_a).to eq(1)
    end

    it "returns nil when comparing with non-MOD objects" do
      expect(mod_a <=> "not a MOD").to be_nil
      expect(mod_a <=> 42).to be_nil
    end
  end

  describe "sorting" do
    it "sorts MODs with base first" do
      mods = [
        Factorix::MOD[name: "z-mod"],
        Factorix::MOD[name: "base"],
        Factorix::MOD[name: "a-mod"],
        Factorix::MOD[name: "m-mod"]
      ]

      sorted = mods.sort
      expect(sorted.map(&:name)).to eq(%w[base a-mod m-mod z-mod])
    end
  end

  describe "immutability" do
    it "is frozen after creation" do
      mod = Factorix::MOD[name: "example-mod"]
      expect(mod).to be_frozen
    end
  end
end
