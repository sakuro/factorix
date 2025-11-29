# frozen_string_literal: true

RSpec.describe Factorix::Dependency::Graph::Builder do
  let(:mod_a) { Factorix::MOD[name: "mod-a"] }
  let(:mod_b) { Factorix::MOD[name: "mod-b"] }
  let(:mod_c) { Factorix::MOD[name: "mod-c"] }
  let(:base_mod) { Factorix::MOD[name: "base"] }

  let(:version_1_0_0) { Factorix::MODVersion.from_string("1.0.0") }
  let(:version_2_0_0) { Factorix::MODVersion.from_string("2.0.0") }

  # Helper to create mock InstalledMOD
  def create_installed_mod(mod:, version:, dependencies: [])
    info = instance_double(
      Factorix::InfoJSON,
      name: mod.name,
      version:,
      dependencies:
    )

    instance_double(
      Factorix::InstalledMOD,
      mod:,
      version:,
      info:
    )
  end

  # Helper to create MODList
  def create_mod_list(states_hash)
    mods = states_hash.transform_values {|enabled|
      Factorix::MODState[enabled:, version: nil]
    }
    Factorix::MODList.new(mods)
  end

  describe ".build" do
    context "with simple MOD without dependencies" do
      let(:installed_mod_a) { create_installed_mod(mod: mod_a, version: version_1_0_0, dependencies: []) }
      let(:mod_list) { create_mod_list(mod_a => true) }

      it "creates graph with single node" do
        graph = Factorix::Dependency::Graph::Builder.build(installed_mods: [installed_mod_a], mod_list:)

        expect(graph.size).to eq(1)
        node = graph.node(mod_a)
        expect(node).not_to be_nil
        expect(node.version).to eq(version_1_0_0)
        expect(node.enabled).to be true
        expect(node.installed).to be true
      end
    end

    context "with MOD that is disabled" do
      let(:installed_mod_a) { create_installed_mod(mod: mod_a, version: version_1_0_0, dependencies: []) }
      let(:mod_list) { create_mod_list(mod_a => false) }

      it "creates node with enabled=false" do
        graph = Factorix::Dependency::Graph::Builder.build(installed_mods: [installed_mod_a], mod_list:)

        node = graph.node(mod_a)
        expect(node.enabled).to be false
        expect(node.installed).to be true
      end
    end

    context "with MOD not in mod-list" do
      let(:installed_mod_a) { create_installed_mod(mod: mod_a, version: version_1_0_0, dependencies: []) }
      let(:mod_list) { create_mod_list({}) }

      it "creates node with enabled=false" do
        graph = Factorix::Dependency::Graph::Builder.build(installed_mods: [installed_mod_a], mod_list:)

        node = graph.node(mod_a)
        expect(node.enabled).to be false
      end
    end

    context "with MOD having dependencies" do
      let(:dep_b) do
        Factorix::Dependency::Entry[
          mod: mod_b,
          type: :required,
          version_requirement: nil
        ]
      end
      let(:installed_mod_a) { create_installed_mod(mod: mod_a, version: version_1_0_0, dependencies: [dep_b]) }
      let(:installed_mod_b) { create_installed_mod(mod: mod_b, version: version_1_0_0, dependencies: []) }
      let(:mod_list) { create_mod_list(mod_a => true, mod_b => true) }

      it "creates graph with dependency edge" do
        graph = Factorix::Dependency::Graph::Builder.build(installed_mods: [installed_mod_a, installed_mod_b], mod_list:)

        expect(graph.size).to eq(2)

        edges = graph.edges_from(mod_a)
        expect(edges.size).to eq(1)
        edge = edges.first
        expect(edge.from_mod).to eq(mod_a)
        expect(edge.to_mod).to eq(mod_b)
        expect(edge.type).to eq(:required)
      end
    end

    context "with base MOD dependency (should be skipped)" do
      let(:dep_base) do
        Factorix::Dependency::Entry[
          mod: base_mod,
          type: :required,
          version_requirement: nil
        ]
      end
      let(:installed_mod_a) { create_installed_mod(mod: mod_a, version: version_1_0_0, dependencies: [dep_base]) }
      let(:mod_list) { create_mod_list(mod_a => true) }

      it "does not create edge for base MOD" do
        graph = Factorix::Dependency::Graph::Builder.build(installed_mods: [installed_mod_a], mod_list:)

        edges = graph.edges_from(mod_a)
        expect(edges).to be_empty
      end
    end

    context "with multiple MODs and dependencies" do
      let(:dep_b) do
        Factorix::Dependency::Entry[
          mod: mod_b,
          type: :required,
          version_requirement: nil
        ]
      end
      let(:dep_c) do
        Factorix::Dependency::Entry[
          mod: mod_c,
          type: :optional,
          version_requirement: nil
        ]
      end
      let(:installed_mod_a) { create_installed_mod(mod: mod_a, version: version_1_0_0, dependencies: [dep_b, dep_c]) }
      let(:installed_mod_b) { create_installed_mod(mod: mod_b, version: version_1_0_0, dependencies: []) }
      let(:installed_mod_c) { create_installed_mod(mod: mod_c, version: version_2_0_0, dependencies: []) }
      let(:mod_list) { create_mod_list(mod_a => true, mod_b => true, mod_c => false) }

      it "creates complete graph" do
        graph = Factorix::Dependency::Graph::Builder.build(
          installed_mods: [installed_mod_a, installed_mod_b, installed_mod_c],
          mod_list:
        )

        expect(graph.size).to eq(3)

        # Check nodes
        node_a = graph.node(mod_a)
        expect(node_a.enabled).to be true
        expect(node_a.version).to eq(version_1_0_0)

        node_b = graph.node(mod_b)
        expect(node_b.enabled).to be true
        expect(node_b.version).to eq(version_1_0_0)

        node_c = graph.node(mod_c)
        expect(node_c.enabled).to be false
        expect(node_c.version).to eq(version_2_0_0)

        # Check edges
        edges_a = graph.edges_from(mod_a)
        expect(edges_a.size).to eq(2)

        required_edge = edges_a.find {|e| e.to_mod == mod_b }
        expect(required_edge.type).to eq(:required)

        optional_edge = edges_a.find {|e| e.to_mod == mod_c }
        expect(optional_edge.type).to eq(:optional)
      end
    end

    context "with version requirements" do
      let(:requirement) do
        Factorix::Dependency::MODVersionRequirement[operator: ">=", version: version_1_0_0]
      end
      let(:dep_b) do
        Factorix::Dependency::Entry[
          mod: mod_b,
          type: :required,
          version_requirement: requirement
        ]
      end
      let(:installed_mod_a) { create_installed_mod(mod: mod_a, version: version_1_0_0, dependencies: [dep_b]) }
      let(:installed_mod_b) { create_installed_mod(mod: mod_b, version: version_2_0_0, dependencies: []) }
      let(:mod_list) { create_mod_list(mod_a => true, mod_b => true) }

      it "includes version requirement in edge" do
        graph = Factorix::Dependency::Graph::Builder.build(installed_mods: [installed_mod_a, installed_mod_b], mod_list:)

        edge = graph.edges_from(mod_a).first
        expect(edge.version_requirement).to eq(requirement)
        expect(edge.satisfied_by?(version_2_0_0)).to be true
      end
    end
  end

  describe "#initialize" do
    it "accepts installed_mods and mod_list" do
      installed_mods = []
      mod_list = create_mod_list({})

      builder = Factorix::Dependency::Graph::Builder.new(installed_mods:, mod_list:)
      expect(builder).to be_a(Factorix::Dependency::Graph::Builder)
    end
  end

  describe "#build" do
    let(:installed_mod_a) { create_installed_mod(mod: mod_a, version: version_1_0_0, dependencies: []) }
    let(:mod_list) { create_mod_list(mod_a => true) }

    it "returns a Graph instance" do
      builder = Factorix::Dependency::Graph::Builder.new(installed_mods: [installed_mod_a], mod_list:)
      graph = builder.build

      expect(graph).to be_a(Factorix::Dependency::Graph)
    end
  end
end
