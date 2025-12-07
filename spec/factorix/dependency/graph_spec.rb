# frozen_string_literal: true

RSpec.describe Factorix::Dependency::Graph do
  let(:mod_a) { Factorix::MOD[name: "mod-a"] }
  let(:mod_b) { Factorix::MOD[name: "mod-b"] }
  let(:mod_c) { Factorix::MOD[name: "mod-c"] }
  let(:version) { Factorix::MODVersion.from_string("1.0.0") }

  let(:node_a) { Factorix::Dependency::Node.new(mod: mod_a, version:) }
  let(:node_b) { Factorix::Dependency::Node.new(mod: mod_b, version:) }
  let(:node_c) { Factorix::Dependency::Node.new(mod: mod_c, version:) }

  describe "#initialize" do
    it "creates an empty graph" do
      graph = Factorix::Dependency::Graph.new

      expect(graph.size).to eq(0)
      expect(graph.empty?).to be true
      expect(graph.nodes).to be_empty
      expect(graph.edges).to be_empty
    end
  end

  describe "#add_node" do
    let(:graph) { Factorix::Dependency::Graph.new }

    it "adds a node to the graph" do
      graph.add_node(node_a)

      expect(graph.size).to eq(1)
      expect(graph.node(mod_a)).to eq(node_a)
      expect(graph.nodes).to eq([node_a])
    end

    it "raises error when adding duplicate node" do
      graph.add_node(node_a)

      expect {
        graph.add_node(node_a)
      }.to raise_error(Factorix::DependencyGraphError, /already exists/)
    end
  end

  describe "#set_node_operation" do
    let(:graph) { Factorix::Dependency::Graph.new }
    let(:node_a_installed) { Factorix::Dependency::Node.new(mod: mod_a, version:, installed: true, enabled: false) }

    before do
      graph.add_node(node_a_installed)
    end

    it "sets the operation of an existing node" do
      graph.set_node_operation(mod_a, :enable)

      updated_node = graph.node(mod_a)
      expect(updated_node.operation).to eq(:enable)
      expect(updated_node.mod).to eq(mod_a)
      expect(updated_node.version).to eq(version)
      expect(updated_node.installed).to be true
      expect(updated_node.enabled).to be false
    end

    it "returns the updated node" do
      result = graph.set_node_operation(mod_a, :enable)

      expect(result.operation).to eq(:enable)
    end

    it "returns nil when node doesn't exist" do
      result = graph.set_node_operation(mod_b, :enable)

      expect(result).to be_nil
    end
  end

  describe "#add_edge" do
    let(:graph) { Factorix::Dependency::Graph.new }
    let(:edge) do
      Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required)
    end

    before do
      graph.add_node(node_a)
      graph.add_node(node_b)
    end

    it "adds an edge to the graph" do
      graph.add_edge(edge)

      expect(graph.edges_from(mod_a)).to eq([edge])
      expect(graph.edges).to eq([edge])
    end

    it "raises error when from_mod node doesn't exist" do
      mod_x = Factorix::MOD[name: "mod-x"]
      edge_x = Factorix::Dependency::Edge.new(from_mod: mod_x, to_mod: mod_b, type: :required)

      expect {
        graph.add_edge(edge_x)
      }.to raise_error(Factorix::DependencyGraphError, /doesn't exist/)
    end
  end

  describe "#node" do
    let(:graph) { Factorix::Dependency::Graph.new }

    it "returns node when it exists" do
      graph.add_node(node_a)
      expect(graph.node(mod_a)).to eq(node_a)
    end

    it "returns nil when node doesn't exist" do
      expect(graph.node(mod_a)).to be_nil
    end
  end

  describe "#node?" do
    let(:graph) { Factorix::Dependency::Graph.new }

    it "returns true when node exists" do
      graph.add_node(node_a)
      expect(graph.node?(mod_a)).to be true
    end

    it "returns false when node doesn't exist" do
      expect(graph.node?(mod_a)).to be false
    end
  end

  describe "#edges_from" do
    let(:graph) { Factorix::Dependency::Graph.new }
    let(:edge1) { Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required) }
    let(:edge2) { Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_c, type: :optional) }

    before do
      graph.add_node(node_a)
      graph.add_node(node_b)
      graph.add_node(node_c)
      graph.add_edge(edge1)
      graph.add_edge(edge2)
    end

    it "returns all edges from a MOD" do
      edges = graph.edges_from(mod_a)
      expect(edges).to contain_exactly(edge1, edge2)
    end

    it "returns empty array when MOD has no edges" do
      expect(graph.edges_from(mod_b)).to be_empty
    end

    it "returns empty array when MOD doesn't exist" do
      mod_x = Factorix::MOD[name: "mod-x"]
      expect(graph.edges_from(mod_x)).to be_empty
    end
  end

  describe "#edges_to" do
    let(:graph) { Factorix::Dependency::Graph.new }
    let(:edge1) { Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required) }
    let(:edge2) { Factorix::Dependency::Edge.new(from_mod: mod_c, to_mod: mod_b, type: :optional) }

    before do
      graph.add_node(node_a)
      graph.add_node(node_b)
      graph.add_node(node_c)
      graph.add_edge(edge1)
      graph.add_edge(edge2)
    end

    it "returns all edges to a MOD" do
      edges = graph.edges_to(mod_b)
      expect(edges).to contain_exactly(edge1, edge2)
    end

    it "returns empty array when MOD has no incoming edges" do
      expect(graph.edges_to(mod_a)).to be_empty
    end

    it "returns empty array when MOD doesn't exist" do
      mod_x = Factorix::MOD[name: "mod-x"]
      expect(graph.edges_to(mod_x)).to be_empty
    end
  end

  describe "#find_enabled_dependents" do
    let(:graph) { Factorix::Dependency::Graph.new }

    context "when MOD has enabled dependents with required dependencies" do
      let(:node_a_enabled) { Factorix::Dependency::Node.new(mod: mod_a, version:, enabled: true) }
      let(:node_b_enabled) { Factorix::Dependency::Node.new(mod: mod_b, version:, enabled: true) }
      let(:node_c_enabled) { Factorix::Dependency::Node.new(mod: mod_c, version:, enabled: true) }
      let(:edge_b_to_a) { Factorix::Dependency::Edge.new(from_mod: mod_b, to_mod: mod_a, type: :required) }
      let(:edge_c_to_a) { Factorix::Dependency::Edge.new(from_mod: mod_c, to_mod: mod_a, type: :required) }

      before do
        graph.add_node(node_a_enabled)
        graph.add_node(node_b_enabled)
        graph.add_node(node_c_enabled)
        graph.add_edge(edge_b_to_a)
        graph.add_edge(edge_c_to_a)
      end

      it "returns MODs that depend on the given MOD" do
        dependents = graph.find_enabled_dependents(mod_a)
        expect(dependents).to contain_exactly(mod_b, mod_c)
      end
    end

    context "when dependent is disabled" do
      let(:node_a_enabled) { Factorix::Dependency::Node.new(mod: mod_a, version:, enabled: true) }
      let(:node_b_disabled) { Factorix::Dependency::Node.new(mod: mod_b, version:, enabled: false) }
      let(:edge_b_to_a) { Factorix::Dependency::Edge.new(from_mod: mod_b, to_mod: mod_a, type: :required) }

      before do
        graph.add_node(node_a_enabled)
        graph.add_node(node_b_disabled)
        graph.add_edge(edge_b_to_a)
      end

      it "does not include disabled MODs" do
        dependents = graph.find_enabled_dependents(mod_a)
        expect(dependents).to be_empty
      end
    end

    context "when dependency is optional" do
      let(:node_a_enabled) { Factorix::Dependency::Node.new(mod: mod_a, version:, enabled: true) }
      let(:node_b_enabled) { Factorix::Dependency::Node.new(mod: mod_b, version:, enabled: true) }
      let(:edge_b_to_a_optional) { Factorix::Dependency::Edge.new(from_mod: mod_b, to_mod: mod_a, type: :optional) }

      before do
        graph.add_node(node_a_enabled)
        graph.add_node(node_b_enabled)
        graph.add_edge(edge_b_to_a_optional)
      end

      it "does not include MODs with optional dependencies" do
        dependents = graph.find_enabled_dependents(mod_a)
        expect(dependents).to be_empty
      end
    end

    context "when MOD has no dependents" do
      let(:node_a_enabled) { Factorix::Dependency::Node.new(mod: mod_a, version:, enabled: true) }

      before do
        graph.add_node(node_a_enabled)
      end

      it "returns empty array" do
        dependents = graph.find_enabled_dependents(mod_a)
        expect(dependents).to be_empty
      end
    end
  end

  describe "#tsort" do
    let(:graph) { Factorix::Dependency::Graph.new }

    context "with simple dependency chain" do
      # A -> B -> C
      before do
        graph.add_node(node_a)
        graph.add_node(node_b)
        graph.add_node(node_c)
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required))
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_b, to_mod: mod_c, type: :required))
      end

      it "returns MODs in dependency order" do
        order = graph.tsort
        expect(order.index(mod_c)).to be < order.index(mod_b)
        expect(order.index(mod_b)).to be < order.index(mod_a)
      end
    end

    context "with diamond dependency" do
      # A -> B -> D
      # A -> C -> D
      let(:mod_d) { Factorix::MOD[name: "mod-d"] }
      let(:node_d) { Factorix::Dependency::Node.new(mod: mod_d, version:) }

      before do
        graph.add_node(node_a)
        graph.add_node(node_b)
        graph.add_node(node_c)
        graph.add_node(node_d)
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required))
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_c, type: :required))
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_b, to_mod: mod_d, type: :required))
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_c, to_mod: mod_d, type: :required))
      end

      it "returns MODs in valid dependency order" do
        order = graph.tsort
        expect(order.index(mod_d)).to be < order.index(mod_b)
        expect(order.index(mod_d)).to be < order.index(mod_c)
        expect(order.index(mod_b)).to be < order.index(mod_a)
        expect(order.index(mod_c)).to be < order.index(mod_a)
      end
    end
  end

  describe "#cyclic?" do
    let(:graph) { Factorix::Dependency::Graph.new }

    context "with acyclic graph" do
      before do
        graph.add_node(node_a)
        graph.add_node(node_b)
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required))
      end

      it "returns false" do
        expect(graph.cyclic?).to be false
      end
    end

    context "with cyclic graph" do
      before do
        graph.add_node(node_a)
        graph.add_node(node_b)
        graph.add_node(node_c)
        # Create cycle: A -> B -> C -> A
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required))
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_b, to_mod: mod_c, type: :required))
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_c, to_mod: mod_a, type: :required))
      end

      it "returns true" do
        expect(graph.cyclic?).to be true
      end

      it "raises TSort::Cyclic when calling tsort" do
        expect { graph.tsort }.to raise_error(TSort::Cyclic)
      end
    end

    context "with incompatible edges (not considered cycles)" do
      before do
        graph.add_node(node_a)
        graph.add_node(node_b)
        # Incompatible edges don't create cycles for topological sort
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :incompatible))
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_b, to_mod: mod_a, type: :incompatible))
      end

      it "returns false" do
        expect(graph.cyclic?).to be false
      end
    end
  end

  describe "#strongly_connected_components" do
    let(:graph) { Factorix::Dependency::Graph.new }

    context "with cycle" do
      before do
        graph.add_node(node_a)
        graph.add_node(node_b)
        graph.add_node(node_c)
        # Create cycle: A -> B -> C -> A
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required))
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_b, to_mod: mod_c, type: :required))
        graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_c, to_mod: mod_a, type: :required))
      end

      it "returns the cycle as a strongly connected component" do
        components = graph.strongly_connected_components
        cycle = components.find {|c| c.size > 1 }
        expect(cycle).to contain_exactly(mod_a, mod_b, mod_c)
      end
    end
  end

  describe "#to_s and #inspect" do
    let(:graph) { Factorix::Dependency::Graph.new }

    before do
      graph.add_node(node_a)
      graph.add_node(node_b)
      graph.add_edge(Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required))
    end

    it "#to_s shows node and edge counts" do
      expect(graph.to_s).to match(/#<Factorix::Dependency::Graph nodes=2 edges=1>/)
    end

    it "#inspect shows node details" do
      expect(graph.inspect).to include("mod-a")
      expect(graph.inspect).to include("mod-b")
    end
  end
end
