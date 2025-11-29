# frozen_string_literal: true

RSpec.describe Factorix::Dependency::Edge do
  let(:mod_a) { Factorix::MOD[name: "mod-a"] }
  let(:mod_b) { Factorix::MOD[name: "mod-b"] }
  let(:version_1_0_0) { Factorix::MODVersion.from_string("1.0.0") }
  let(:version_2_0_0) { Factorix::MODVersion.from_string("2.0.0") }
  let(:requirement) do
    Factorix::Dependency::MODVersionRequirement[operator: ">=", version: version_1_0_0]
  end

  describe "#initialize" do
    it "creates an edge with minimal parameters" do
      edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required)

      expect(edge.from_mod).to eq(mod_a)
      expect(edge.to_mod).to eq(mod_b)
      expect(edge.type).to eq(:required)
      expect(edge.version_requirement).to be_nil
    end

    it "creates an edge with version requirement" do
      edge = Factorix::Dependency::Edge.new(
        from_mod: mod_a,
        to_mod: mod_b,
        type: :required,
        version_requirement: requirement
      )

      expect(edge.from_mod).to eq(mod_a)
      expect(edge.to_mod).to eq(mod_b)
      expect(edge.type).to eq(:required)
      expect(edge.version_requirement).to eq(requirement)
    end
  end

  describe "type predicates" do
    it "#required? returns true for required edges" do
      edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required)
      expect(edge.required?).to be true
      expect(edge.optional?).to be false
      expect(edge.incompatible?).to be false
      expect(edge.load_neutral?).to be false
    end

    it "#optional? returns true for optional edges" do
      edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :optional)
      expect(edge.required?).to be false
      expect(edge.optional?).to be true
      expect(edge.incompatible?).to be false
      expect(edge.load_neutral?).to be false
    end

    it "#optional? returns true for hidden optional edges" do
      edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :hidden)
      expect(edge.required?).to be false
      expect(edge.optional?).to be true
      expect(edge.incompatible?).to be false
      expect(edge.load_neutral?).to be false
    end

    it "#incompatible? returns true for incompatible edges" do
      edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :incompatible)
      expect(edge.required?).to be false
      expect(edge.optional?).to be false
      expect(edge.incompatible?).to be true
      expect(edge.load_neutral?).to be false
    end

    it "#load_neutral? returns true for load-neutral edges" do
      edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :load_neutral)
      expect(edge.required?).to be false
      expect(edge.optional?).to be false
      expect(edge.incompatible?).to be false
      expect(edge.load_neutral?).to be true
    end
  end

  describe "#satisfied_by?" do
    context "without version requirement" do
      let(:edge) { Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required) }

      it "returns true for any version" do
        expect(edge.satisfied_by?(version_1_0_0)).to be true
        expect(edge.satisfied_by?(version_2_0_0)).to be true
      end
    end

    context "with version requirement" do
      let(:edge) do
        Factorix::Dependency::Edge.new(
          from_mod: mod_a,
          to_mod: mod_b,
          type: :required,
          version_requirement: requirement
        )
      end

      it "returns true when version satisfies requirement" do
        expect(edge.satisfied_by?(version_1_0_0)).to be true
        expect(edge.satisfied_by?(version_2_0_0)).to be true
      end

      it "returns false when version does not satisfy requirement" do
        version_0_9_0 = Factorix::MODVersion.from_string("0.9.0")
        expect(edge.satisfied_by?(version_0_9_0)).to be false
      end
    end
  end

  describe "constants" do
    it "exposes dependency type constants" do
      expect(Factorix::Dependency::Edge::REQUIRED).to eq(:required)
      expect(Factorix::Dependency::Edge::OPTIONAL).to eq(:optional)
      expect(Factorix::Dependency::Edge::HIDDEN_OPTIONAL).to eq(:hidden)
      expect(Factorix::Dependency::Edge::INCOMPATIBLE).to eq(:incompatible)
      expect(Factorix::Dependency::Edge::LOAD_NEUTRAL).to eq(:load_neutral)
    end
  end

  describe "#to_s" do
    it "shows edge without version requirement" do
      edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required)
      expect(edge.to_s).to eq("mod-a --[required]--> mod-b")
    end

    it "shows edge with version requirement" do
      edge = Factorix::Dependency::Edge.new(
        from_mod: mod_a,
        to_mod: mod_b,
        type: :required,
        version_requirement: requirement
      )
      expect(edge.to_s).to eq("mod-a --[required >= 1.0.0]--> mod-b")
    end
  end

  describe "#inspect" do
    it "includes class name and to_s output" do
      edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required)
      expect(edge.inspect).to match(/^#<Factorix::Dependency::Edge mod-a --\[required\]--> mod-b>$/)
    end
  end
end
