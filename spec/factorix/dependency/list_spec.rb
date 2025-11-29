# frozen_string_literal: true

RSpec.describe Factorix::Dependency::List do
  let(:version_1_0_0) { Factorix::MODVersion.from_string("1.0.0") }
  let(:version_1_2_0) { Factorix::MODVersion.from_string("1.2.0") }
  let(:version_2_0_0) { Factorix::MODVersion.from_string("2.0.0") }

  let(:base_mod) { Factorix::MOD[name: "base"] }
  let(:required_mod) { Factorix::MOD[name: "required-mod"] }
  let(:optional_mod) { Factorix::MOD[name: "optional-mod"] }
  let(:hidden_mod) { Factorix::MOD[name: "hidden-mod"] }
  let(:incompatible_mod) { Factorix::MOD[name: "incompatible-mod"] }
  let(:neutral_mod) { Factorix::MOD[name: "neutral-mod"] }

  let(:requirement_ge_1_2_0) do
    Factorix::Dependency::MODVersionRequirement[operator: ">=", version: version_1_2_0]
  end

  describe ".from_strings" do
    it "creates instance from array of dependency strings" do
      deps = Factorix::Dependency::List.from_strings(["base", "? optional-mod"])
      expect(deps).to be_a(Factorix::Dependency::List)
      expect(deps.size).to eq(2)
    end

    it "parses all dependency types correctly" do
      deps = Factorix::Dependency::List.from_strings([
        "base",
        "? optional-mod",
        "(?) hidden-mod",
        "! incompatible-mod",
        "~ neutral-mod"
      ])

      expect(deps.required.size).to eq(1)
      expect(deps.optional.size).to eq(2)
      expect(deps.incompatible.size).to eq(1)
      expect(deps.load_neutral.size).to eq(1)
    end

    it "parses version requirements" do
      deps = Factorix::Dependency::List.from_strings(["required-mod >= 1.2.0"])
      dep = deps.first
      expect(dep.version_requirement).not_to be_nil
      expect(dep.version_requirement.operator).to eq(">=")
      expect(dep.version_requirement.version).to eq(version_1_2_0)
    end

    it "raises ArgumentError for invalid dependency string" do
      expect {
        Factorix::Dependency::List.from_strings([""])
      }.to raise_error(ArgumentError)
    end
  end

  describe ".new" do
    context "with valid dependencies array" do
      it "creates instance" do
        dep = Factorix::Dependency::Entry[mod: base_mod, type: :required]
        deps = Factorix::Dependency::List.new([dep])
        expect(deps.size).to eq(1)
      end
    end

    context "with empty array" do
      it "creates empty instance" do
        deps = Factorix::Dependency::List.new([])
        expect(deps).to be_empty
        expect(deps.size).to eq(0)
      end
    end

    context "with no arguments" do
      it "creates empty instance" do
        deps = Factorix::Dependency::List.new
        expect(deps).to be_empty
      end
    end

    context "with invalid arguments" do
      it "raises ArgumentError when not an Array" do
        expect {
          Factorix::Dependency::List.new("not an array")
        }.to raise_error(ArgumentError, /must be an Array/)
      end

      it "raises ArgumentError when element is not Dependency::Entry" do
        expect {
          Factorix::Dependency::List.new(["not a dependency"])
        }.to raise_error(ArgumentError, /must be a Dependency::Entry/)
      end
    end
  end

  describe "#each" do
    let(:deps) do
      Factorix::Dependency::List.from_strings(["base", "? optional-mod"])
    end

    context "with block" do
      it "iterates through all dependencies" do
        names = deps.map {|dep| dep.mod.name }
        expect(names).to eq(%w[base optional-mod])
      end

      it "returns self" do
        result = []
        expect(deps.each {|dep| result << dep }).to eq(deps)
      end
    end

    context "without block" do
      it "returns Enumerator" do
        expect(deps.each).to be_a(Enumerator)
      end

      it "Enumerator yields all dependencies" do
        names = deps.each.map {|dep| dep.mod.name }
        expect(names).to eq(%w[base optional-mod])
      end
    end
  end

  describe "filter methods" do
    let(:deps) do
      Factorix::Dependency::List.new([
        Factorix::Dependency::Entry[mod: required_mod, type: :required],
        Factorix::Dependency::Entry[mod: optional_mod, type: :optional],
        Factorix::Dependency::Entry[mod: hidden_mod, type: :hidden],
        Factorix::Dependency::Entry[mod: incompatible_mod, type: :incompatible],
        Factorix::Dependency::Entry[mod: neutral_mod, type: :load_neutral]
      ])
    end

    describe "#required" do
      it "returns only required dependencies" do
        result = deps.required
        expect(result.size).to eq(1)
        expect(result.first.mod.name).to eq("required-mod")
      end
    end

    describe "#optional" do
      it "returns optional and hidden optional dependencies" do
        result = deps.optional
        expect(result.size).to eq(2)
        names = result.map {|dep| dep.mod.name }
        expect(names).to contain_exactly("optional-mod", "hidden-mod")
      end
    end

    describe "#incompatible" do
      it "returns only incompatible dependencies" do
        result = deps.incompatible
        expect(result.size).to eq(1)
        expect(result.first.mod.name).to eq("incompatible-mod")
      end
    end

    describe "#load_neutral" do
      it "returns only load-neutral dependencies" do
        result = deps.load_neutral
        expect(result.size).to eq(1)
        expect(result.first.mod.name).to eq("neutral-mod")
      end
    end
  end

  describe "#depends_on?" do
    let(:deps) do
      Factorix::Dependency::List.new([
        Factorix::Dependency::Entry[mod: required_mod, type: :required],
        Factorix::Dependency::Entry[mod: incompatible_mod, type: :incompatible]
      ])
    end

    it "returns true for required dependency (String argument)" do
      expect(deps.depends_on?("required-mod")).to be(true)
    end

    it "returns true for required dependency (MOD argument)" do
      expect(deps.depends_on?(required_mod)).to be(true)
    end

    it "returns false for incompatible dependency" do
      expect(deps.depends_on?("incompatible-mod")).to be(false)
    end

    it "returns false for non-existent dependency" do
      expect(deps.depends_on?("unknown-mod")).to be(false)
    end
  end

  describe "#incompatible_with?" do
    let(:deps) do
      Factorix::Dependency::List.new([
        Factorix::Dependency::Entry[mod: required_mod, type: :required],
        Factorix::Dependency::Entry[mod: incompatible_mod, type: :incompatible]
      ])
    end

    it "returns true for incompatible dependency (String argument)" do
      expect(deps.incompatible_with?("incompatible-mod")).to be(true)
    end

    it "returns true for incompatible dependency (MOD argument)" do
      expect(deps.incompatible_with?(incompatible_mod)).to be(true)
    end

    it "returns false for required dependency" do
      expect(deps.incompatible_with?("required-mod")).to be(false)
    end

    it "returns false for non-existent dependency" do
      expect(deps.incompatible_with?("unknown-mod")).to be(false)
    end
  end

  describe "#empty?" do
    it "returns true for empty dependencies" do
      deps = Factorix::Dependency::List.new([])
      expect(deps.empty?).to be(true)
    end

    it "returns false for non-empty dependencies" do
      deps = Factorix::Dependency::List.from_strings(["base"])
      expect(deps.empty?).to be(false)
    end
  end

  describe "#size" do
    it "returns 0 for empty dependencies" do
      deps = Factorix::Dependency::List.new
      expect(deps.size).to eq(0)
    end

    it "returns correct count for non-empty dependencies" do
      deps = Factorix::Dependency::List.from_strings(["base", "? optional-mod", "! bad-mod"])
      expect(deps.size).to eq(3)
    end
  end

  describe "#satisfied_by?" do
    let(:deps) do
      Factorix::Dependency::List.new([
        Factorix::Dependency::Entry[mod: base_mod, type: :required],
        Factorix::Dependency::Entry[mod: required_mod, type: :required, version_requirement: requirement_ge_1_2_0],
        Factorix::Dependency::Entry[mod: optional_mod, type: :optional]
      ])
    end

    context "when all required dependencies are satisfied" do
      it "returns true" do
        available = {
          "base" => version_1_0_0,
          "required-mod" => version_2_0_0
        }
        expect(deps.satisfied_by?(available)).to be(true)
      end
    end

    context "when a required dependency is missing" do
      it "returns false" do
        available = {
          "base" => version_1_0_0
        }
        expect(deps.satisfied_by?(available)).to be(false)
      end
    end

    context "when a version requirement is not satisfied" do
      it "returns false" do
        available = {
          "base" => version_1_0_0,
          "required-mod" => version_1_0_0
        }
        expect(deps.satisfied_by?(available)).to be(false)
      end
    end

    context "when optional dependency is missing" do
      it "returns true (optional is not required)" do
        available = {
          "base" => version_1_0_0,
          "required-mod" => version_2_0_0
        }
        expect(deps.satisfied_by?(available)).to be(true)
      end
    end
  end

  describe "#conflicts_with?" do
    let(:deps) do
      Factorix::Dependency::List.new([
        Factorix::Dependency::Entry[mod: incompatible_mod, type: :incompatible],
        Factorix::Dependency::Entry[mod: Factorix::MOD[name: "another-bad-mod"], type: :incompatible]
      ])
    end

    it "returns empty array when no conflicts" do
      available = {"base" => version_1_0_0}
      expect(deps.conflicts_with?(available)).to eq([])
    end

    it "returns array of conflicting MOD names" do
      available = {
        "base" => version_1_0_0,
        "incompatible-mod" => version_1_0_0
      }
      expect(deps.conflicts_with?(available)).to eq(["incompatible-mod"])
    end

    it "returns all conflicting MODs" do
      available = {
        "incompatible-mod" => version_1_0_0,
        "another-bad-mod" => version_1_0_0
      }
      expect(deps.conflicts_with?(available)).to contain_exactly("incompatible-mod", "another-bad-mod")
    end
  end

  describe "#missing_required" do
    let(:deps) do
      Factorix::Dependency::List.new([
        Factorix::Dependency::Entry[mod: base_mod, type: :required],
        Factorix::Dependency::Entry[mod: required_mod, type: :required],
        Factorix::Dependency::Entry[mod: optional_mod, type: :optional]
      ])
    end

    it "returns empty array when all required deps are available" do
      available = {
        "base" => version_1_0_0,
        "required-mod" => version_1_0_0
      }
      expect(deps.missing_required(available)).to eq([])
    end

    it "returns missing required dependency names" do
      available = {"base" => version_1_0_0}
      expect(deps.missing_required(available)).to eq(["required-mod"])
    end

    it "does not include optional dependencies" do
      available = {}
      missing = deps.missing_required(available)
      expect(missing).not_to include("optional-mod")
      expect(missing).to contain_exactly("base", "required-mod")
    end
  end

  describe "#unsatisfied_versions" do
    let(:deps) do
      Factorix::Dependency::List.new([
        Factorix::Dependency::Entry[mod: base_mod, type: :required],
        Factorix::Dependency::Entry[mod: required_mod, type: :required, version_requirement: requirement_ge_1_2_0]
      ])
    end

    it "returns empty hash when all versions are satisfied" do
      available = {
        "base" => version_1_0_0,
        "required-mod" => version_2_0_0
      }
      expect(deps.unsatisfied_versions(available)).to eq({})
    end

    it "returns hash of unsatisfied dependencies" do
      available = {
        "base" => version_1_0_0,
        "required-mod" => version_1_0_0
      }
      result = deps.unsatisfied_versions(available)
      expect(result).to have_key("required-mod")
      expect(result["required-mod"][:required]).to eq(">= 1.2.0")
      expect(result["required-mod"][:actual]).to eq("1.0.0")
    end

    it "does not include dependencies without version requirements" do
      available = {
        "base" => version_1_0_0,
        "required-mod" => version_2_0_0
      }
      result = deps.unsatisfied_versions(available)
      expect(result).not_to have_key("base")
    end

    it "does not include missing dependencies (covered by missing_required)" do
      available = {"base" => version_1_0_0}
      result = deps.unsatisfied_versions(available)
      expect(result).to eq({})
    end
  end

  describe ".detect_circular" do
    context "with no cycles" do
      it "returns empty array for empty map" do
        expect(Factorix::Dependency::List.detect_circular({})).to eq([])
      end

      it "returns empty array when no dependencies" do
        map = {
          "mod-a" => Factorix::Dependency::List.new([]),
          "mod-b" => Factorix::Dependency::List.new([])
        }
        expect(Factorix::Dependency::List.detect_circular(map)).to eq([])
      end

      it "returns empty array for linear dependencies" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(["base"]),
          "mod-b" => Factorix::Dependency::List.from_strings(["mod-a"]),
          "mod-c" => Factorix::Dependency::List.from_strings(["mod-b"])
        }
        expect(Factorix::Dependency::List.detect_circular(map)).to eq([])
      end

      it "returns empty array for tree structure" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(["base"]),
          "mod-b" => Factorix::Dependency::List.from_strings(["base"]),
          "mod-c" => Factorix::Dependency::List.from_strings(%w[mod-a mod-b])
        }
        expect(Factorix::Dependency::List.detect_circular(map)).to eq([])
      end
    end

    context "with cycles" do
      it "detects simple 2-node cycle" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(["mod-b"]),
          "mod-b" => Factorix::Dependency::List.from_strings(["mod-a"])
        }
        cycles = Factorix::Dependency::List.detect_circular(map)
        expect(cycles.size).to eq(1)
        expect(cycles.first).to eq(%w[mod-a mod-b mod-a]).or eq(%w[mod-b mod-a mod-b])
      end

      it "detects 3-node cycle" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(["mod-b"]),
          "mod-b" => Factorix::Dependency::List.from_strings(["mod-c"]),
          "mod-c" => Factorix::Dependency::List.from_strings(["mod-a"])
        }
        cycles = Factorix::Dependency::List.detect_circular(map)
        expect(cycles.size).to eq(1)
        cycle = cycles.first
        # Cycle can start from any node
        expect(cycle.first).to eq(cycle.last)
        expect(cycle.size).to eq(4) # A -> B -> C -> A
      end

      it "detects self-dependency" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(["mod-a"])
        }
        cycles = Factorix::Dependency::List.detect_circular(map)
        expect(cycles.size).to eq(1)
        expect(cycles.first).to eq(%w[mod-a mod-a])
      end

      it "detects multiple disconnected cycles" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(["mod-b"]),
          "mod-b" => Factorix::Dependency::List.from_strings(["mod-a"]),
          "mod-c" => Factorix::Dependency::List.from_strings(["mod-d"]),
          "mod-d" => Factorix::Dependency::List.from_strings(["mod-c"])
        }
        cycles = Factorix::Dependency::List.detect_circular(map)
        expect(cycles.size).to eq(2)
      end
    end

    context "with optional dependencies" do
      it "does not detect cycles through optional dependencies" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(["? mod-b"]),
          "mod-b" => Factorix::Dependency::List.from_strings(["? mod-a"])
        }
        expect(Factorix::Dependency::List.detect_circular(map)).to eq([])
      end

      it "detects cycles only through required dependencies" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(["mod-b", "? mod-c"]),
          "mod-b" => Factorix::Dependency::List.from_strings(["mod-a"]),
          "mod-c" => Factorix::Dependency::List.from_strings(["? mod-a"])
        }
        cycles = Factorix::Dependency::List.detect_circular(map)
        expect(cycles.size).to eq(1)
        # Cycle should only include mod-a and mod-b
        cycle = cycles.first
        expect(cycle).to include("mod-a", "mod-b")
        expect(cycle).not_to include("mod-c")
      end
    end

    context "with load-neutral dependencies" do
      it "does not detect cycles through load-neutral dependencies" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(["~ mod-b"]),
          "mod-b" => Factorix::Dependency::List.from_strings(["~ mod-a"])
        }
        expect(Factorix::Dependency::List.detect_circular(map)).to eq([])
      end
    end

    context "with incompatible dependencies" do
      it "does not detect cycles through incompatible dependencies" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(["! mod-b"]),
          "mod-b" => Factorix::Dependency::List.from_strings(["! mod-a"])
        }
        expect(Factorix::Dependency::List.detect_circular(map)).to eq([])
      end
    end

    context "with complex dependency graphs" do
      it "detects cycles in graphs with multiple paths" do
        map = {
          "mod-a" => Factorix::Dependency::List.from_strings(%w[mod-b mod-c]),
          "mod-b" => Factorix::Dependency::List.from_strings(["mod-d"]),
          "mod-c" => Factorix::Dependency::List.from_strings(["mod-d"]),
          "mod-d" => Factorix::Dependency::List.from_strings(["mod-a"])
        }
        cycles = Factorix::Dependency::List.detect_circular(map)
        expect(cycles.size).to be >= 1
        # Should detect at least one cycle involving mod-a and mod-d
        expect(cycles.any? {|c| c.include?("mod-a") && c.include?("mod-d") }).to be(true)
      end
    end
  end

  describe "#to_a" do
    it "returns array of dependency strings" do
      deps = Factorix::Dependency::List.from_strings(["base", "? optional-mod >= 1.0.0"])
      result = deps.to_a
      expect(result).to be_a(Array)
      expect(result.size).to eq(2)
      expect(result).to include("base")
      expect(result).to include("? optional-mod >= 1.0.0")
    end

    it "returns empty array for empty dependencies" do
      deps = Factorix::Dependency::List.new
      expect(deps.to_a).to eq([])
    end
  end

  describe "#to_h" do
    it "returns hash keyed by MOD name" do
      deps = Factorix::Dependency::List.from_strings(["base", "? optional-mod"])
      result = deps.to_h
      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly("base", "optional-mod")
      expect(result["base"]).to be_a(Factorix::Dependency::Entry)
      expect(result["base"].mod.name).to eq("base")
    end

    it "returns empty hash for empty dependencies" do
      deps = Factorix::Dependency::List.new
      expect(deps.to_h).to eq({})
    end
  end
end
