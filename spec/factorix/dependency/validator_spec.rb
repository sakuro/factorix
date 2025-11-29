# frozen_string_literal: true

RSpec.describe Factorix::Dependency::Validator do
  let(:mod_a) { Factorix::MOD[name: "mod-a"] }
  let(:mod_b) { Factorix::MOD[name: "mod-b"] }
  let(:mod_c) { Factorix::MOD[name: "mod-c"] }
  let(:version_1_0_0) { Factorix::MODVersion.from_string("1.0.0") }
  let(:version_2_0_0) { Factorix::MODVersion.from_string("2.0.0") }

  describe "#validate" do
    context "with valid graph" do
      it "returns valid result with no errors" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        graph.add_node(node_a)

        validator = Factorix::Dependency::Validator.new(graph)
        result = validator.validate

        expect(result.valid?).to be true
        expect(result.errors).to be_empty
        expect(result.warnings).to be_empty
      end
    end

    context "when circular dependency exists" do
      it "detects circular dependency" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        node_b = Factorix::Dependency::Node.new(mod: mod_b, version: version_1_0_0, enabled: true, installed: true)
        graph.add_node(node_a)
        graph.add_node(node_b)

        # Create circular dependency: A -> B -> A
        edge_a_to_b = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required)
        edge_b_to_a = Factorix::Dependency::Edge.new(from_mod: mod_b, to_mod: mod_a, type: :required)
        graph.add_edge(edge_a_to_b)
        graph.add_edge(edge_b_to_a)

        validator = Factorix::Dependency::Validator.new(graph)
        result = validator.validate

        expect(result.valid?).to be false
        expect(result.errors.size).to eq(1)
        error = result.errors.first
        expect(error.type).to eq(:circular_dependency)
        expect(error.message).to include("Circular dependency detected")
      end
    end

    context "when dependencies are missing" do
      it "detects missing required dependency" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        graph.add_node(node_a)

        # A requires B, but B is not installed
        edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required)
        graph.add_edge(edge)

        validator = Factorix::Dependency::Validator.new(graph)
        result = validator.validate

        expect(result.valid?).to be false
        expect(result.errors.size).to eq(1)
        error = result.errors.first
        expect(error.type).to eq(:missing_dependency)
        expect(error.message).to include("mod-a")
        expect(error.message).to include("mod-b")
        expect(error.message).to include("not installed")
        expect(error.mod).to eq(mod_a)
        expect(error.dependency).to eq(mod_b)
      end

      it "ignores optional dependencies" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        graph.add_node(node_a)

        # A optionally depends on B (not installed) - should not error
        edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :optional)
        graph.add_edge(edge)

        validator = Factorix::Dependency::Validator.new(graph)
        result = validator.validate

        expect(result.valid?).to be true
        expect(result.errors).to be_empty
      end
    end

    context "when dependencies are disabled" do
      it "detects disabled required dependency" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        node_b = Factorix::Dependency::Node.new(mod: mod_b, version: version_1_0_0, enabled: false, installed: true)
        graph.add_node(node_a)
        graph.add_node(node_b)

        # A requires B, but B is disabled
        edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required)
        graph.add_edge(edge)

        validator = Factorix::Dependency::Validator.new(graph)
        result = validator.validate

        expect(result.valid?).to be false
        expect(result.errors.size).to eq(1)
        error = result.errors.first
        expect(error.type).to eq(:disabled_dependency)
        expect(error.message).to include("mod-a")
        expect(error.message).to include("mod-b")
        expect(error.message).to include("not enabled")
        expect(error.mod).to eq(mod_a)
        expect(error.dependency).to eq(mod_b)
      end
    end

    context "when version requirements are not satisfied" do
      it "detects version mismatch" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        node_b = Factorix::Dependency::Node.new(mod: mod_b, version: version_1_0_0, enabled: true, installed: true)
        graph.add_node(node_a)
        graph.add_node(node_b)

        # A requires B >= 2.0.0, but B is 1.0.0
        requirement = Factorix::Dependency::MODVersionRequirement[operator: ">=", version: version_2_0_0]
        edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required, version_requirement: requirement)
        graph.add_edge(edge)

        validator = Factorix::Dependency::Validator.new(graph)
        result = validator.validate

        expect(result.valid?).to be false
        expect(result.errors.size).to eq(1)
        error = result.errors.first
        expect(error.type).to eq(:version_mismatch)
        expect(error.message).to include("mod-a")
        expect(error.message).to include("mod-b")
        expect(error.message).to include("version")
        expect(error.mod).to eq(mod_a)
        expect(error.dependency).to eq(mod_b)
      end

      it "accepts satisfied version requirement" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        node_b = Factorix::Dependency::Node.new(mod: mod_b, version: version_2_0_0, enabled: true, installed: true)
        graph.add_node(node_a)
        graph.add_node(node_b)

        # A requires B >= 2.0.0, and B is 2.0.0 - should be valid
        requirement = Factorix::Dependency::MODVersionRequirement[operator: ">=", version: version_2_0_0]
        edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required, version_requirement: requirement)
        graph.add_edge(edge)

        validator = Factorix::Dependency::Validator.new(graph)
        result = validator.validate

        expect(result.valid?).to be true
        expect(result.errors).to be_empty
      end
    end

    context "when conflicts exist" do
      it "detects conflict between enabled MODs" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        node_b = Factorix::Dependency::Node.new(mod: mod_b, version: version_1_0_0, enabled: true, installed: true)
        graph.add_node(node_a)
        graph.add_node(node_b)

        # A conflicts with B, and both are enabled
        edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :incompatible)
        graph.add_edge(edge)

        validator = Factorix::Dependency::Validator.new(graph)
        result = validator.validate

        expect(result.valid?).to be false
        expect(result.errors.size).to eq(1)
        error = result.errors.first
        expect(error.type).to eq(:conflict)
        expect(error.message).to include("mod-a")
        expect(error.message).to include("mod-b")
        expect(error.message).to include("conflicts")
        expect(error.mod).to eq(mod_a)
        expect(error.dependency).to eq(mod_b)
      end

      it "ignores conflict when one MOD is disabled" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        node_b = Factorix::Dependency::Node.new(mod: mod_b, version: version_1_0_0, enabled: false, installed: true)
        graph.add_node(node_a)
        graph.add_node(node_b)

        # A conflicts with B, but B is disabled - should be valid
        edge = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :incompatible)
        graph.add_edge(edge)

        validator = Factorix::Dependency::Validator.new(graph)
        result = validator.validate

        expect(result.valid?).to be true
        expect(result.errors).to be_empty
      end
    end

    context "when MOD list is provided" do
      it "warns about MOD in list but not installed" do
        graph = Factorix::Dependency::Graph.new
        mod_list = instance_double(Factorix::MODList)
        allow(mod_list).to receive(:each_mod).and_yield(mod_a)
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(true)

        # mod_a is in list but not in graph (not installed)
        validator = Factorix::Dependency::Validator.new(graph, mod_list:)
        result = validator.validate

        expect(result.valid?).to be true # Warnings don't affect validity
        expect(result.warnings.size).to eq(1)
        warning = result.warnings.first
        expect(warning.type).to eq(:mod_in_list_not_installed)
        expect(warning.message).to include("mod-a")
        expect(warning.message).to include("mod-list.json")
        expect(warning.message).to include("not installed")
        expect(warning.mod).to eq(mod_a)
      end

      it "warns about installed MOD not in list" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        graph.add_node(node_a)

        mod_list = instance_double(Factorix::MODList)
        allow(mod_list).to receive(:each_mod) # No MODs in list
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(false)

        # mod_a is installed but not in mod_list
        validator = Factorix::Dependency::Validator.new(graph, mod_list:)
        result = validator.validate

        expect(result.valid?).to be true # Warnings don't affect validity
        expect(result.warnings.size).to eq(1)
        warning = result.warnings.first
        expect(warning.type).to eq(:mod_installed_not_in_list)
        expect(warning.message).to include("mod-a")
        expect(warning.message).to include("mod-list.json")
        expect(warning.mod).to eq(mod_a)
      end

      it "does not validate MOD list when not provided" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        graph.add_node(node_a)

        # No mod_list provided - should not generate warnings
        validator = Factorix::Dependency::Validator.new(graph)
        result = validator.validate

        expect(result.valid?).to be true
        expect(result.warnings).to be_empty
      end
    end

    context "when multiple errors occur" do
      it "reports multiple errors and warnings" do
        graph = Factorix::Dependency::Graph.new
        node_a = Factorix::Dependency::Node.new(mod: mod_a, version: version_1_0_0, enabled: true, installed: true)
        node_b = Factorix::Dependency::Node.new(mod: mod_b, version: version_1_0_0, enabled: false, installed: true)
        graph.add_node(node_a)
        graph.add_node(node_b)

        # A requires B (disabled) - error
        edge1 = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_b, type: :required)
        graph.add_edge(edge1)

        # A requires C (missing) - error
        edge2 = Factorix::Dependency::Edge.new(from_mod: mod_a, to_mod: mod_c, type: :required)
        graph.add_edge(edge2)

        mod_list = instance_double(Factorix::MODList)
        allow(mod_list).to receive(:each_mod)  # No MODs in list
        allow(mod_list).to receive(:exist?).and_return(false)

        validator = Factorix::Dependency::Validator.new(graph, mod_list:)
        result = validator.validate

        expect(result.valid?).to be false
        expect(result.errors.size).to eq(2)
        expect(result.warnings.size).to eq(2)  # mod_a and mod_b not in list
      end
    end
  end
end
