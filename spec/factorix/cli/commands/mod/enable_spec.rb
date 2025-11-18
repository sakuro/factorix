# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Enable do
  let(:command) { Factorix::CLI::Commands::MOD::Enable.new }
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
    # Runtime is already mocked by "with mock runtime" shared context
    allow(Factorix::Runtime).to receive(:detect).and_return(runtime)
    allow(runtime).to receive_messages(mod_list_path:, mod_dir:, data_dir:)

    # Mock Application.load_config
    allow(Factorix::Application).to receive(:load_config)

    # Mock MODList
    allow(Factorix::MODList).to receive(:load).and_return(mod_list)
    allow(mod_list).to receive(:save)
    allow(mod_list).to receive(:enable)

    # Mock InstalledMOD.all
    allow(Factorix::InstalledMOD).to receive(:all).and_return([])

    # Mock Graph::Builder
    allow(Factorix::Dependency::Graph::Builder).to receive(:build).and_return(graph)
    allow(graph).to receive(:node?)
    allow(graph).to receive(:node)
    allow(graph).to receive(:edges_from).and_return([])
  end

  describe "#call" do
    context "when enabling a single MOD without dependencies" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:edges_from).with(mod_a).and_return([])
      end

      it "enables the MOD" do
        capture_stdout { command.call(mod_names: ["mod-a"], yes: true) }
        expect(mod_list).to have_received(:enable).with(mod_a)
      end

      it "saves the mod-list.json" do
        capture_stdout { command.call(mod_names: ["mod-a"], yes: true) }
        expect(mod_list).to have_received(:save).with(to: mod_list_path)
      end

      it "displays the plan" do
        expect { command.call(mod_names: ["mod-a"], yes: true) }
          .to output(/Planning to enable 1 MOD/).to_stdout
      end
    end

    context "when enabling a MOD with dependencies" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false, version: "1.0.0") }
      let(:node_b) { instance_double(Factorix::Dependency::Node, mod: mod_b, enabled?: false, version: "1.0.0") }
      let(:edge_a_to_b) do
        instance_double(
          Factorix::Dependency::Edge,
          required?: true,
          incompatible?: false,
          to_mod: mod_b,
          version_requirement: ">=1.0.0",
          satisfied_by?: true
        )
      end

      before do
        # mod-a depends on mod-b
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node?).with(mod_b).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:node).with(mod_b).and_return(node_b)
        allow(graph).to receive(:edges_from).with(mod_a).and_return([edge_a_to_b])
        allow(graph).to receive(:edges_from).with(mod_b).and_return([])
        allow(edge_a_to_b).to receive(:satisfied_by?).with("1.0.0").and_return(true)
      end

      it "enables both the MOD and its dependency" do
        capture_stdout { command.call(mod_names: ["mod-a"], yes: true) }
        expect(mod_list).to have_received(:enable).with(mod_a)
        expect(mod_list).to have_received(:enable).with(mod_b)
      end

      it "displays both MODs in the plan" do
        expect { command.call(mod_names: ["mod-a"], yes: true) }
          .to output(/Planning to enable 2 MOD/).to_stdout
      end
    end

    context "when enabling a MOD that is already enabled" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: true) }

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
      end

      it "does not enable the MOD again" do
        capture_stdout { command.call(mod_names: ["mod-a"], yes: true) }
        expect(mod_list).not_to have_received(:enable)
      end

      it "displays that all MODs are already enabled" do
        expect { command.call(mod_names: ["mod-a"], yes: true) }
          .to output(/All specified MODs are already enabled/).to_stdout
      end
    end

    context "with --only flag" do
      context "when dependency is already enabled" do
        let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false, version: "1.0.0") }
        let(:node_b) { instance_double(Factorix::Dependency::Node, mod: mod_b, enabled?: true, version: "1.0.0") }
        let(:edge_a_to_b) do
          instance_double(
            Factorix::Dependency::Edge,
            required?: true,
            incompatible?: false,
            to_mod: mod_b,
            version_requirement: ">=1.0.0",
            satisfied_by?: true
          )
        end

        before do
          # mod_b is a regular MOD (not base), so base? returns false automatically
          allow(graph).to receive(:node?).with(mod_a).and_return(true)
          allow(graph).to receive(:node).with(mod_a).and_return(node_a)
          allow(graph).to receive(:node).with(mod_b).and_return(node_b)
          allow(graph).to receive(:edges_from).with(mod_a).and_return([edge_a_to_b])
          allow(edge_a_to_b).to receive(:satisfied_by?).with("1.0.0").and_return(true)
        end

        it "enables only the specified MOD" do
          capture_stdout { command.call(mod_names: ["mod-a"], only: true, yes: true) }
          expect(mod_list).to have_received(:enable).with(mod_a)
          expect(mod_list).not_to have_received(:enable).with(mod_b)
        end
      end

      context "when dependency is not enabled" do
        let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false, version: "1.0.0") }
        let(:node_b) { instance_double(Factorix::Dependency::Node, mod: mod_b, enabled?: false, version: "1.0.0") }
        let(:edge_a_to_b) do
          instance_double(
            Factorix::Dependency::Edge,
            required?: true,
            to_mod: mod_b
          )
        end

        before do
          # mod_b is a regular MOD (not base), so base? returns false automatically
          allow(graph).to receive(:node?).with(mod_a).and_return(true)
          allow(graph).to receive(:node).with(mod_a).and_return(node_a)
          allow(graph).to receive(:node).with(mod_b).and_return(node_b)
          allow(graph).to receive(:edges_from).with(mod_a).and_return([edge_a_to_b])
        end

        it "raises an error" do
          expect { capture_stdout { command.call(mod_names: ["mod-a"], only: true, yes: true) } }
            .to raise_error(Factorix::Error, /dependency mod-b is not enabled/)
        end
      end
    end

    context "when MOD has a conflict" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false, version: "1.0.0") }
      let(:node_c) { instance_double(Factorix::Dependency::Node, mod: mod_c, enabled?: true, version: "1.0.0") }
      let(:edge_a_to_c) do
        instance_double(
          Factorix::Dependency::Edge,
          required?: false,
          incompatible?: true,
          to_mod: mod_c
        )
      end

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:node).with(mod_c).and_return(node_c)
        allow(graph).to receive(:edges_from).with(mod_a).and_return([edge_a_to_c])
      end

      it "raises an error about the conflict" do
        expect { capture_stdout { command.call(mod_names: ["mod-a"], yes: true) } }
          .to raise_error(Factorix::Error, /conflicts with mod-c/)
      end
    end

    context "when MOD is not installed" do
      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(false)
      end

      it "raises an error" do
        expect { capture_stdout { command.call(mod_names: ["mod-a"], yes: true) } }
          .to raise_error(Factorix::Error, /not installed/)
      end
    end

    context "with confirmation prompt" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:edges_from).with(mod_a).and_return([])
      end

      context "when user confirms" do
        before do
          allow($stdin).to receive(:gets).and_return("y\n")
        end

        it "enables the MOD" do
          capture_stdout { command.call(mod_names: ["mod-a"]) }
          expect(mod_list).to have_received(:enable).with(mod_a)
        end
      end

      context "when user declines" do
        before do
          allow($stdin).to receive(:gets).and_return("n\n")
        end

        it "does not enable the MOD" do
          capture_stdout { command.call(mod_names: ["mod-a"]) }
          expect(mod_list).not_to have_received(:enable)
        end
      end
    end

    context "when game is running" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }

      before do
        allow(runtime).to receive(:running?).and_return(true)
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:edges_from).with(mod_a).and_return([])
      end

      it "displays an error message and exits" do
        expect { command.call(mod_names: ["mod-a"], yes: true) }
          .to output(/Cannot perform this operation while Factorio is running/).to_stdout
          .and raise_error(SystemExit)
      end
    end
  end
end
