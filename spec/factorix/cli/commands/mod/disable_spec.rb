# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Disable do
  include_context "with suppressed output"

  let(:runtime) do
    instance_double(
      Factorix::Runtime::Base,
      factorix_config_path: Pathname("/tmp/factorix/config.rb"),
      mod_list_path:,
      mod_dir:,
      data_dir:,
      running?: false
    )
  end
  let(:logger) { instance_double(Dry::Logger::Dispatcher, debug: nil) }
  let(:command) { Factorix::CLI::Commands::MOD::Disable.new(runtime:, logger:) }
  let(:mod_list_path) { Pathname("/fake/path/mod-list.json") }
  let(:mod_dir) { Pathname("/fake/path/mods") }
  let(:data_dir) { Pathname("/fake/path/data") }
  let(:mod_list) { instance_spy(Factorix::MODList) }
  let(:graph) { instance_spy(Factorix::Dependency::Graph) }

  # Test MODs
  let(:mod_a) { Factorix::MOD[name: "mod-a"] }
  let(:mod_b) { Factorix::MOD[name: "mod-b"] }
  let(:mod_c) { Factorix::MOD[name: "mod-c"] }

  before do
    allow(Factorix::Application).to receive(:load_config)
    allow(Factorix::MODList).to receive(:load).and_return(mod_list)
    allow(mod_list).to receive(:save)
    allow(mod_list).to receive(:disable)
    allow(Factorix::InstalledMOD).to receive(:all).and_return([])
    allow(Factorix::Dependency::Graph::Builder).to receive(:build).and_return(graph)
    allow(graph).to receive(:node?)
    allow(graph).to receive(:node)
    allow(graph).to receive_messages(nodes: [], edges_from: [])

    # Stub load_current_state to return mocked state
    # (Validator is tested separately in validator_spec.rb)
    allow(command).to receive(:load_current_state).and_return([graph, mod_list, []])
  end

  describe "#call" do
    context "when disabling a single MOD without dependents" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: true) }

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:nodes).and_return([node_a])
      end

      it "disables the MOD" do
        capture_stdout { command.call(mod_names: ["mod-a"], yes: true) }
        expect(mod_list).to have_received(:disable).with(mod_a)
      end

      it "saves the mod-list.json" do
        command.call(mod_names: ["mod-a"], yes: true)
        expect(mod_list).to have_received(:save).with(mod_list_path)
      end
    end

    context "when disabling a MOD with dependents" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: true) }
      let(:node_b) { instance_double(Factorix::Dependency::Node, mod: mod_b, enabled?: true) }
      let(:edge_b_to_a) do
        instance_double(
          Factorix::Dependency::Edge,
          required?: true,
          to_mod: mod_a
        )
      end

      before do
        # mod-b depends on mod-a, so disabling mod-a should also disable mod-b
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:node).with(mod_b).and_return(node_b)

        # Mock the nodes iteration for find_enabled_dependents
        # When find_enabled_dependents is called with mod_a, it should find node_b as a dependent
        # This happens because node_b has an edge to mod_a
        allow(graph).to receive(:nodes).and_return([node_a, node_b])

        # For the algorithm to work:
        # - edges_from(mod_a) returns [] (mod-a doesn't depend on anything)
        # - edges_from(mod_b) returns [edge to mod-a] (mod-b depends on mod-a)
        allow(graph).to receive(:edges_from).with(mod_a).and_return([])
        allow(graph).to receive(:edges_from).with(mod_b).and_return([edge_b_to_a])
      end

      it "disables both the MOD and its dependents" do
        command.call(mod_names: ["mod-a"], yes: true)
        expect(mod_list).to have_received(:disable).with(mod_a)
        expect(mod_list).to have_received(:disable).with(mod_b)
      end
    end

    context "when disabling a MOD that is already disabled" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
      end

      it "does not disable the MOD again" do
        command.call(mod_names: ["mod-a"], yes: true)
        expect(mod_list).not_to have_received(:disable)
      end
    end

    context "when trying to disable base MOD" do
      let(:base_mod) { Factorix::MOD[name: "base"] }

      before do
        allow(graph).to receive(:node?).with(base_mod).and_return(true)
      end

      it "raises an error" do
        expect { capture_stdout { command.call(mod_names: ["base"], yes: true) } }
          .to raise_error(Factorix::Error, /Cannot disable base MOD/)
      end
    end

    context "with confirmation prompt" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: true) }

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:nodes).and_return([node_a])
      end

      context "when user confirms" do
        before do
          allow($stdin).to receive(:gets).and_return("y\n")
        end

        it "disables the MOD" do
          capture_stdout { command.call(mod_names: ["mod-a"]) }
          expect(mod_list).to have_received(:disable).with(mod_a)
        end
      end

      context "when user declines" do
        before do
          allow($stdin).to receive(:gets).and_return("n\n")
        end

        it "does not disable the MOD" do
          capture_stdout { command.call(mod_names: ["mod-a"]) }
          expect(mod_list).not_to have_received(:disable)
        end
      end
    end

    context "when game is running" do
      let(:runtime) do
        instance_double(
          Factorix::Runtime::Base,
          factorix_config_path: Pathname("/tmp/factorix/config.rb"),
          mod_list_path:,
          mod_dir:,
          data_dir:,
          running?: true
        )
      end
      let(:logger) { instance_double(Dry::Logger::Dispatcher, debug: nil, error: nil) }
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: true) }

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
      end

      it "raises GameRunningError" do
        expect { command.call(mod_names: ["mod-a"], yes: true) }
          .to raise_error(Factorix::GameRunningError, /Cannot perform this operation while Factorio is running/)
      end
    end

    context "with --all option" do
      let(:base_mod) { Factorix::MOD[name: "base"] }
      let(:expansion_mod) { Factorix::MOD[name: "space-age"] }
      let(:node_base) { instance_double(Factorix::Dependency::Node, mod: base_mod, enabled?: true) }
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: true) }
      let(:node_b) { instance_double(Factorix::Dependency::Node, mod: mod_b, enabled?: false) }
      let(:node_expansion) { instance_double(Factorix::Dependency::Node, mod: expansion_mod, enabled?: true) }

      before do
        allow(graph).to receive_messages(nodes: [node_base, node_a, node_b, node_expansion], node?: true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:node).with(expansion_mod).and_return(node_expansion)
      end

      it "disables all enabled MODs except base" do
        capture_stdout { command.call(all: true, yes: true) }
        expect(mod_list).to have_received(:disable).with(mod_a)
        expect(mod_list).to have_received(:disable).with(expansion_mod)
        expect(mod_list).not_to have_received(:disable).with(base_mod)
      end

      it "does not disable already disabled MODs" do
        command.call(all: true, yes: true)
        expect(mod_list).not_to have_received(:disable).with(mod_b)
      end

      it "raises error when used with MOD names" do
        expect { capture_stdout { command.call(mod_names: ["mod-a"], all: true, yes: true) } }
          .to raise_error(Factorix::Error, /Cannot specify MOD names with --all option/)
      end
    end

    context "without MOD names or --all option" do
      it "raises error" do
        expect { capture_stdout { command.call(yes: true) } }
          .to raise_error(Factorix::Error, /Must specify MOD names or use --all option/)
      end
    end
  end
end
