# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Uninstall do
  include_context "with suppressed output"

  let(:runtime) do
    instance_double(
      Factorix::Runtime::Base,
      factorix_config_path: Pathname("/tmp/factorix/config.rb"),
      running?: false
    )
  end
  let(:logger) { instance_double(Dry::Logger::Dispatcher, debug: nil, info: nil, warn: nil, error: nil) }

  let(:command) { Factorix::CLI::Commands::MOD::Uninstall.new(runtime:, logger:) }
  let(:mod_list_path) { Pathname("/fake/path/mod-list.json") }
  let(:mod_dir) { Pathname("/fake/path/mods") }
  let(:data_dir) { Pathname("/fake/path/data") }
  let(:mod_list) { instance_spy(Factorix::MODList) }
  let(:graph) { instance_spy(Factorix::Dependency::Graph) }

  # Test MODs
  let(:mod_a) { Factorix::MOD[name: "mod-a"] }
  let(:mod_b) { Factorix::MOD[name: "mod-b"] }
  let(:mod_c) { Factorix::MOD[name: "mod-c"] }

  # Test InstalledMODs
  let(:installed_mod_a) do
    instance_double(
      Factorix::InstalledMOD,
      mod: mod_a,
      version: Factorix::MODVersion.from_string("1.0.0"),
      path: Pathname("/fake/path/mods/mod-a_1.0.0"),
      form: Factorix::InstalledMOD::DIRECTORY_FORM
    )
  end

  before do
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:runtime).and_return(runtime)
    allow(Factorix::Container).to receive(:[]).with(:logger).and_return(logger)

    allow(runtime).to receive_messages(mod_list_path:, mod_dir:, data_dir:)

    allow(Factorix::Container).to receive(:load_config)
    allow(Factorix::MODList).to receive(:load).and_return(mod_list)
    allow(mod_list).to receive(:save)
    allow(mod_list).to receive(:remove)
    allow(mod_list).to receive(:exist?)
    allow(Factorix::InstalledMOD).to receive(:all).and_return([])
    allow(Factorix::Dependency::Graph::Builder).to receive(:build).and_return(graph)
    allow(graph).to receive(:node?)
    allow(graph).to receive_messages(nodes: [], find_enabled_dependents: [])
  end

  describe "#call" do
    context "when uninstalling a single MOD without dependents" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:nodes).and_return([node_a])
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a])
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(true)
      end

      it "removes the MOD files" do
        allow(installed_mod_a.path).to receive(:rmtree)
        command.call(mod_specs: ["mod-a"], yes: true)
        expect(installed_mod_a.path).to have_received(:rmtree)
      end

      it "removes the MOD from mod-list.json" do
        allow(installed_mod_a.path).to receive(:rmtree)
        command.call(mod_specs: ["mod-a"], yes: true)
        expect(mod_list).to have_received(:remove).with(mod_a)
      end

      it "saves the mod-list.json" do
        allow(installed_mod_a.path).to receive(:rmtree)
        command.call(mod_specs: ["mod-a"], yes: true)
        expect(mod_list).to have_received(:save).with(no_args)
      end
    end

    context "when uninstalling a MOD with enabled dependents" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }
      let(:node_b) { instance_double(Factorix::Dependency::Node, mod: mod_b, enabled?: true) }
      let(:edge_b_to_a) do
        instance_double(
          Factorix::Dependency::Edge,
          required?: true,
          to_mod: mod_a,
          satisfied_by?: true
        )
      end

      before do
        # mod-b depends on mod-a, so uninstalling mod-a should fail
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:nodes).and_return([node_a, node_b])
        allow(graph).to receive(:find_enabled_dependents).with(mod_a).and_return([mod_b])
        allow(graph).to receive(:edges_from).with(mod_b).and_return([edge_b_to_a])
      end

      it "raises an error" do
        expect { command.call(mod_specs: ["mod-a"], yes: true) }
          .to raise_error(Factorix::Error, /following enabled MOD\(s\) depend on it/)
      end
    end

    context "when trying to uninstall base MOD" do
      let(:base_mod) { Factorix::MOD[name: "base"] }

      before do
        allow(graph).to receive(:node?).with(base_mod).and_return(true)
      end

      it "raises an error" do
        expect { command.call(mod_specs: ["base"], yes: true) }
          .to raise_error(Factorix::Error, /Cannot uninstall base MOD/)
      end
    end

    context "when trying to uninstall expansion MOD" do
      let(:expansion_mod) { Factorix::MOD[name: "space-age"] }

      before do
        allow(graph).to receive(:node?).with(expansion_mod).and_return(true)
      end

      it "raises an error" do
        expect { command.call(mod_specs: ["space-age"], yes: true) }
          .to raise_error(Factorix::Error, /Cannot uninstall expansion MOD/)
      end
    end

    context "when trying to uninstall a MOD that is not installed" do
      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(false)
      end

      it "does not modify mod-list.json" do
        command.call(mod_specs: ["mod-a"], yes: true)
        expect(mod_list).not_to have_received(:save)
      end
    end

    context "when uninstalling a ZIP MOD" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }
      let(:installed_mod_a_zip) do
        instance_double(
          Factorix::InstalledMOD,
          mod: mod_a,
          version: Factorix::MODVersion.from_string("1.0.0"),
          path: Pathname("/fake/path/mods/mod-a_1.0.0.zip"),
          form: Factorix::InstalledMOD::ZIP_FORM
        )
      end

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:nodes).and_return([node_a])
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a_zip])
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(true)
        allow(installed_mod_a_zip.path).to receive(:delete)
      end

      it "deletes the ZIP file" do
        command.call(mod_specs: ["mod-a"], yes: true)
        expect(installed_mod_a_zip.path).to have_received(:delete)
      end
    end

    context "when uninstalling a MOD with multiple versions" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }
      let(:installed_mod_a_v1) do
        instance_double(
          Factorix::InstalledMOD,
          mod: mod_a,
          version: Factorix::MODVersion.from_string("1.0.0"),
          path: Pathname("/fake/path/mods/mod-a_1.0.0"),
          form: Factorix::InstalledMOD::DIRECTORY_FORM
        )
      end
      let(:installed_mod_a_v2) do
        instance_double(
          Factorix::InstalledMOD,
          mod: mod_a,
          version: Factorix::MODVersion.from_string("2.0.0"),
          path: Pathname("/fake/path/mods/mod-a_2.0.0"),
          form: Factorix::InstalledMOD::DIRECTORY_FORM
        )
      end

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:nodes).and_return([node_a])
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a_v1, installed_mod_a_v2])
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(true)
        allow(installed_mod_a_v1.path).to receive(:rmtree)
        allow(installed_mod_a_v2.path).to receive(:rmtree)
      end

      it "removes all versions" do
        command.call(mod_specs: ["mod-a"], yes: true)
        expect(installed_mod_a_v1.path).to have_received(:rmtree)
        expect(installed_mod_a_v2.path).to have_received(:rmtree)
      end
    end

    context "when uninstalling a specific version (mod@version)" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }
      let(:installed_mod_a_v1) do
        instance_double(
          Factorix::InstalledMOD,
          mod: mod_a,
          version: Factorix::MODVersion.from_string("1.0.0"),
          path: Pathname("/fake/path/mods/mod-a_1.0.0"),
          form: Factorix::InstalledMOD::DIRECTORY_FORM
        )
      end
      let(:installed_mod_a_v2) do
        instance_double(
          Factorix::InstalledMOD,
          mod: mod_a,
          version: Factorix::MODVersion.from_string("2.0.0"),
          path: Pathname("/fake/path/mods/mod-a_2.0.0"),
          form: Factorix::InstalledMOD::DIRECTORY_FORM
        )
      end

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:nodes).and_return([node_a])
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a_v1, installed_mod_a_v2])
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(true)
        allow(installed_mod_a_v1.path).to receive(:rmtree)
        allow(installed_mod_a_v2.path).to receive(:rmtree)
      end

      it "removes only the specified version" do
        command.call(mod_specs: ["mod-a@1.0.0"], yes: true)
        expect(installed_mod_a_v1.path).to have_received(:rmtree)
        expect(installed_mod_a_v2.path).not_to have_received(:rmtree)
      end

      it "does not remove from mod-list.json when other versions remain" do
        command.call(mod_specs: ["mod-a@1.0.0"], yes: true)
        expect(mod_list).not_to have_received(:remove)
      end
    end

    context "when uninstalling all versions of a MOD with version notation" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }
      let(:installed_mod_a_v1) do
        instance_double(
          Factorix::InstalledMOD,
          mod: mod_a,
          version: Factorix::MODVersion.from_string("1.0.0"),
          path: Pathname("/fake/path/mods/mod-a_1.0.0"),
          form: Factorix::InstalledMOD::DIRECTORY_FORM
        )
      end
      let(:installed_mod_a_v2) do
        instance_double(
          Factorix::InstalledMOD,
          mod: mod_a,
          version: Factorix::MODVersion.from_string("2.0.0"),
          path: Pathname("/fake/path/mods/mod-a_2.0.0"),
          form: Factorix::InstalledMOD::DIRECTORY_FORM
        )
      end

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:nodes).and_return([node_a])
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a_v1, installed_mod_a_v2])
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(true)
        allow(installed_mod_a_v1.path).to receive(:rmtree)
        allow(installed_mod_a_v2.path).to receive(:rmtree)
      end

      it "removes all versions when last version is uninstalled" do
        # First uninstall v1
        command.call(mod_specs: ["mod-a@1.0.0"], yes: true)
        # Then uninstall v2 - should now remove from mod-list
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a_v2])
        command.call(mod_specs: ["mod-a@2.0.0"], yes: true)
        expect(mod_list).to have_received(:remove).with(mod_a)
      end
    end

    context "with confirmation prompt" do
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:nodes).and_return([node_a])
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a])
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(true)
        allow(installed_mod_a.path).to receive(:rmtree)
      end

      context "when user confirms" do
        before do
          allow($stdin).to receive(:gets).and_return("y\n")
        end

        it "uninstalls the MOD" do
          command.call(mod_specs: ["mod-a"])
          expect(mod_list).to have_received(:remove).with(mod_a)
        end
      end

      context "when user declines" do
        before do
          allow($stdin).to receive(:gets).and_return("n\n")
        end

        it "does not uninstall the MOD" do
          command.call(mod_specs: ["mod-a"])
          expect(mod_list).not_to have_received(:remove)
        end
      end
    end

    context "when game is running" do
      let(:version) { Factorix::MODVersion.from_string("1.0.0") }
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false, version:) }

      before do
        allow(runtime).to receive(:running?).and_return(true)
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
      end

      it "raises GameRunningError" do
        expect { command.call(mod_specs: ["mod-a"], yes: true) }
          .to raise_error(Factorix::GameRunningError, /Cannot perform this operation while Factorio is running/)
      end
    end

    context "with --all option" do
      let(:expansion_mod) { Factorix::MOD[name: "space-age"] }
      let(:node_a) { instance_double(Factorix::Dependency::Node, mod: mod_a, enabled?: false) }
      let(:node_expansion) { instance_double(Factorix::Dependency::Node, mod: expansion_mod, enabled?: true) }

      before do
        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive_messages(nodes: [node_a, node_expansion], edges_from: [])
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a])
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(true)
        allow(mod_list).to receive(:exist?).with(expansion_mod).and_return(true)
        allow(mod_list).to receive(:enabled?).with(expansion_mod).and_return(true)
        allow(mod_list).to receive(:disable)
        allow(installed_mod_a.path).to receive(:rmtree)
      end

      it "raises error when MOD specs are also provided" do
        expect { command.call(mod_specs: ["mod-a"], all: true, yes: true) }
          .to raise_error(Factorix::Error, /Cannot specify MOD names with --all option/)
      end

      it "uninstalls all regular MODs" do
        command.call(all: true, yes: true)
        expect(installed_mod_a.path).to have_received(:rmtree)
      end

      it "disables expansion MODs" do
        command.call(all: true, yes: true)
        expect(mod_list).to have_received(:disable).with(expansion_mod)
      end
    end

    context "with --all option but no mod_specs argument" do
      it "raises error when neither --all nor mod_specs provided" do
        expect { command.call(yes: true) }
          .to raise_error(Factorix::Error, /Must specify MOD names or use --all option/)
      end
    end
  end
end
