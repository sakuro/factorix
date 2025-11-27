# frozen_string_literal: true

RSpec.describe Factorix::Dependency::Entry do
  let(:version_1_2_0) { Factorix::Types::MODVersion.from_string("1.2.0") }
  let(:version_1_3_0) { Factorix::Types::MODVersion.from_string("1.3.0") }
  let(:requirement) do
    Factorix::Types::MODVersionRequirement[operator: ">=", version: version_1_2_0]
  end

  describe ".new" do
    context "with valid parameters" do
      it "creates a required dependency without version requirement" do
        dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "base"], type: :required]
        expect(dep.mod.name).to eq("base")
        expect(dep.type).to eq(:required)
        expect(dep.version_requirement).to be_nil
      end

      it "creates an optional dependency with version requirement" do
        dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "some-mod"], type: :optional, version_requirement: requirement]
        expect(dep.mod.name).to eq("some-mod")
        expect(dep.type).to eq(:optional)
        expect(dep.version_requirement).to eq(requirement)
      end

      it "creates an incompatible dependency" do
        dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "bad-mod"], type: :incompatible]
        expect(dep.type).to eq(:incompatible)
      end

      it "creates a hidden optional dependency" do
        dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "hidden-mod"], type: :hidden]
        expect(dep.type).to eq(:hidden)
      end

      it "creates a load-neutral dependency" do
        dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "neutral-mod"], type: :load_neutral]
        expect(dep.type).to eq(:load_neutral)
      end
    end

    context "with invalid type" do
      it "raises ArgumentError" do
        expect {
          Factorix::Dependency::Entry[mod: Factorix::MOD[name: "some-mod"], type: :invalid]
        }.to raise_error(ArgumentError, /Invalid dependency type/)
      end
    end

    context "with invalid version_requirement" do
      it "raises ArgumentError when not a MODVersionRequirement" do
        expect {
          Factorix::Dependency::Entry[mod: Factorix::MOD[name: "some-mod"], type: :required, version_requirement: ">= 1.2.0"]
        }.to raise_error(ArgumentError, /version_requirement must be a MODVersionRequirement/)
      end
    end
  end

  describe "#required?" do
    it "returns true for required dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "base"], type: :required]
      expect(dep.required?).to be(true)
    end

    it "returns false for optional dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "mod"], type: :optional]
      expect(dep.required?).to be(false)
    end

    it "returns false for incompatible dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "mod"], type: :incompatible]
      expect(dep.required?).to be(false)
    end
  end

  describe "#optional?" do
    it "returns true for optional dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "mod"], type: :optional]
      expect(dep.optional?).to be(true)
    end

    it "returns true for hidden optional dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "mod"], type: :hidden]
      expect(dep.optional?).to be(true)
    end

    it "returns false for required dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "mod"], type: :required]
      expect(dep.optional?).to be(false)
    end
  end

  describe "#incompatible?" do
    it "returns true for incompatible dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "bad-mod"], type: :incompatible]
      expect(dep.incompatible?).to be(true)
    end

    it "returns false for required dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "mod"], type: :required]
      expect(dep.incompatible?).to be(false)
    end
  end

  describe "#load_neutral?" do
    it "returns true for load-neutral dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "mod"], type: :load_neutral]
      expect(dep.load_neutral?).to be(true)
    end

    it "returns false for required dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "mod"], type: :required]
      expect(dep.load_neutral?).to be(false)
    end
  end

  describe "#satisfied_by?" do
    context "without version requirement" do
      let(:dep) { Factorix::Dependency::Entry[mod: Factorix::MOD[name: "base"], type: :required] }

      it "returns true for any version" do
        expect(dep.satisfied_by?(version_1_2_0)).to be(true)
        expect(dep.satisfied_by?(version_1_3_0)).to be(true)
      end
    end

    context "with version requirement" do
      let(:dep) do
        Factorix::Dependency::Entry[mod: Factorix::MOD[name: "some-mod"], type: :required, version_requirement: requirement]
      end

      it "returns true when version satisfies requirement" do
        expect(dep.satisfied_by?(version_1_2_0)).to be(true)
        expect(dep.satisfied_by?(version_1_3_0)).to be(true)
      end

      it "returns false when version does not satisfy requirement" do
        version_1_0_0 = Factorix::Types::MODVersion.from_string("1.0.0")
        expect(dep.satisfied_by?(version_1_0_0)).to be(false)
      end
    end
  end

  describe "#to_s" do
    it "returns MOD name for required dependency without version" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "base"], type: :required]
      expect(dep.to_s).to eq("base")
    end

    it "returns MOD name with requirement for required dependency with version" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "some-mod"], type: :required, version_requirement: requirement]
      expect(dep.to_s).to eq("some-mod >= 1.2.0")
    end

    it "returns '? mod-name' for optional dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "opt-mod"], type: :optional]
      expect(dep.to_s).to eq("? opt-mod")
    end

    it "returns '(?) mod-name' for hidden optional dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "hidden-mod"], type: :hidden]
      expect(dep.to_s).to eq("(?) hidden-mod")
    end

    it "returns '! mod-name' for incompatible dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "bad-mod"], type: :incompatible]
      expect(dep.to_s).to eq("! bad-mod")
    end

    it "returns '~ mod-name' for load-neutral dependency" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "neutral-mod"], type: :load_neutral]
      expect(dep.to_s).to eq("~ neutral-mod")
    end

    it "includes version requirement when present" do
      dep = Factorix::Dependency::Entry[mod: Factorix::MOD[name: "opt-mod"], type: :optional, version_requirement: requirement]
      expect(dep.to_s).to eq("? opt-mod >= 1.2.0")
    end
  end
end
