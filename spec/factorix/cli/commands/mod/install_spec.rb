# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Install do
  include_context "with mock runtime"

  let(:command) { Factorix::CLI::Commands::MOD::Install.new }
  let(:mod_list_path) { Pathname("/fake/path/mod-list.json") }
  let(:mod_dir) { Pathname("/fake/path/mods") }
  let(:data_dir) { Pathname("/fake/path/data") }
  let(:mod_list) { instance_spy(Factorix::MODList) }
  let(:graph) { instance_spy(Factorix::Dependency::Graph) }
  let(:portal) { instance_spy(Factorix::Portal) }

  # Test MODs
  let(:mod_a) { Factorix::MOD[name: "mod-a"] }
  let(:mod_b) { Factorix::MOD[name: "mod-b"] }

  # Test MODInfo
  let(:mod_info_a) do
    instance_double(
      Factorix::Types::MODInfo,
      name: "mod-a",
      category: Factorix::Types::Category.for("content"),
      releases: [release_a]
    )
  end

  # Test Release
  let(:release_a) do
    instance_double(
      Factorix::Types::Release,
      version: Factorix::Types::MODVersion.from_string("1.0.0"),
      file_name: "mod-a_1.0.0.zip",
      info_json: {dependencies: []},
      released_at: Time.now
    )
  end

  before do
    allow(runtime).to receive_messages(mod_list_path:, mod_dir:, data_dir:)

    # Mock Application.load_config
    allow(Factorix::Application).to receive(:load_config)

    # Mock Progress::Presenter to avoid tty-progressbar issues in tests
    presenter = instance_double(Factorix::Progress::Presenter)
    allow(presenter).to receive(:start)
    allow(presenter).to receive(:update)
    allow(Factorix::Progress::Presenter).to receive(:new).and_return(presenter)

    # Mock Progress::MultiPresenter for download progress
    multi_presenter = instance_double(Factorix::Progress::MultiPresenter)
    allow(multi_presenter).to receive(:register).and_return(presenter)
    allow(Factorix::Progress::MultiPresenter).to receive(:new).and_return(multi_presenter)

    # Mock MODList
    allow(Factorix::MODList).to receive(:load).and_return(mod_list)
    allow(mod_list).to receive(:save)
    allow(mod_list).to receive(:add)
    allow(mod_list).to receive(:enable)
    allow(mod_list).to receive(:exist?)
    allow(mod_list).to receive(:enabled?)

    # Mock InstalledMOD.all
    allow(Factorix::InstalledMOD).to receive(:all).and_return([])

    # Mock Graph::Builder
    allow(Factorix::Dependency::Graph::Builder).to receive(:build).and_return(graph)
    allow(graph).to receive(:add_uninstalled_mod)
    allow(graph).to receive_messages(nodes: [], node?: false, node: nil, edges_from: [], cyclic?: false, topological_order: [])

    # Stub load_current_state to return mocked state
    allow(command).to receive_messages(portal:, load_current_state: [graph, mod_list, []])

    # Mock mod_dir
    allow(mod_dir).to receive(:mkpath)
    allow(mod_dir).to receive_messages(exist?: true, "/": Pathname("/fake/path/mods/mod-a_1.0.0.zip"))

    # Mock portal
    allow(portal).to receive(:download_mod)

    # Mock Application[:portal]
    allow(Factorix::Application).to receive(:[]).with(:portal).and_return(portal)

    # Mock downloader for parallel downloads
    downloader = instance_double(Factorix::Transfer::Downloader)
    allow(downloader).to receive(:subscribe)
    allow(downloader).to receive(:unsubscribe)
    mod_download_api = instance_double(Factorix::API::MODDownloadAPI, downloader:)
    allow(portal).to receive_messages(get_mod_full: mod_info_a, mod_download_api:)
  end

  describe "#call" do
    context "when installing a single MOD without dependencies" do
      let(:node_a) do
        instance_double(
          Factorix::Dependency::Node,
          mod: mod_a,
          version: Factorix::Types::MODVersion.from_string("1.0.0"),
          operation: :install
        )
      end

      before do
        install_targets = [
          {
            mod: mod_a,
            mod_info: mod_info_a,
            release: release_a,
            output_path: mod_dir / "mod-a_1.0.0.zip",
            category: Factorix::Types::Category.for("content")
          }
        ]

        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive_messages(nodes: [node_a], topological_order: [mod_a])
        allow(command).to receive(:plan_installation).and_return(install_targets)
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(false)
      end

      it "downloads the MOD" do
        capture_stdout { command.call(mod_specs: ["mod-a"], yes: true) }
        expect(portal).to have_received(:download_mod)
      end

      it "adds the MOD to mod-list.json" do
        capture_stdout { command.call(mod_specs: ["mod-a"], yes: true) }
        expect(mod_list).to have_received(:add).with(mod_a, enabled: true)
      end

      it "saves mod-list.json" do
        capture_stdout { command.call(mod_specs: ["mod-a"], yes: true) }
        expect(mod_list).to have_received(:save).with(mod_list_path)
      end

      it "displays the plan" do
        expect { command.call(mod_specs: ["mod-a"], yes: true) }
          .to output(/Planning to install 1 MOD/).to_stdout
      end
    end

    context "when installing a MOD with dependencies" do
      let(:node_a) do
        instance_double(
          Factorix::Dependency::Node,
          mod: mod_a,
          version: Factorix::Types::MODVersion.from_string("1.0.0"),
          operation: :install
        )
      end

      let(:node_b) do
        instance_double(
          Factorix::Dependency::Node,
          mod: mod_b,
          version: Factorix::Types::MODVersion.from_string("1.0.0"),
          operation: :install
        )
      end

      let(:mod_info_b) do
        instance_double(
          Factorix::Types::MODInfo,
          name: "mod-b",
          category: Factorix::Types::Category.for("internal"),
          releases: [release_b]
        )
      end

      let(:release_b) do
        instance_double(
          Factorix::Types::Release,
          version: Factorix::Types::MODVersion.from_string("1.0.0"),
          file_name: "mod-b_1.0.0.zip",
          info_json: {dependencies: []},
          released_at: Time.now
        )
      end

      before do
        # mod-a depends on mod-b
        {
          "mod-a" => {mod_name: "mod-a", mod_info: mod_info_a, release: release_a},
          "mod-b" => {mod_name: "mod-b", mod_info: mod_info_b, release: release_b}
        }

        install_targets = [
          {
            mod: mod_b,
            mod_info: mod_info_b,
            release: release_b,
            output_path: mod_dir / "mod-b_1.0.0.zip",
            category: Factorix::Types::Category.for("internal")
          },
          {
            mod: mod_a,
            mod_info: mod_info_a,
            release: release_a,
            output_path: mod_dir / "mod-a_1.0.0.zip",
            category: Factorix::Types::Category.for("content")
          }
        ]

        allow(graph).to receive_messages(nodes: [node_a, node_b], topological_order: [mod_b, mod_a])
        allow(command).to receive(:plan_installation).and_return(install_targets)
        allow(mod_list).to receive(:exist?).and_return(false)
      end

      it "downloads both MODs in dependency order" do
        capture_stdout { command.call(mod_specs: ["mod-a"], yes: true) }
        expect(portal).to have_received(:download_mod).twice
      end

      it "displays both MODs in the plan" do
        expect { command.call(mod_specs: ["mod-a"], yes: true) }
          .to output(/Planning to install 2 MOD/).to_stdout
      end
    end

    context "when MOD is already installed and enabled" do
      before do
        # Empty install targets
        allow(graph).to receive_messages(nodes: [], topological_order: [])
      end

      it "displays a message" do
        expect { command.call(mod_specs: ["mod-a"], yes: true) }
          .to output(/All specified MODs are already installed and enabled/).to_stdout
      end

      it "does not download anything" do
        capture_stdout { command.call(mod_specs: ["mod-a"], yes: true) }
        expect(portal).not_to have_received(:download_mod)
      end
    end

    context "with version specification" do
      before do
        allow(portal).to receive(:get_mod_full).and_return(mod_info_a)
      end

      it "accepts name@version format" do
        # Allow the command to proceed without actual download
        allow(graph).to receive(:nodes).and_return([])
        capture_stdout { command.call(mod_specs: ["mod-a@1.0.0"], yes: true) }
        expect(portal).to have_received(:get_mod_full).with("mod-a")
      end

      it "accepts name@latest format" do
        allow(graph).to receive(:nodes).and_return([])
        capture_stdout { command.call(mod_specs: ["mod-a@latest"], yes: true) }
        expect(portal).to have_received(:get_mod_full).with("mod-a")
      end
    end

    context "with confirmation prompt" do
      let(:node_a) do
        instance_double(
          Factorix::Dependency::Node,
          mod: mod_a,
          version: Factorix::Types::MODVersion.from_string("1.0.0"),
          operation: :install
        )
      end

      before do
        install_targets = [
          {
            mod: mod_a,
            mod_info: mod_info_a,
            release: release_a,
            output_path: mod_dir / "mod-a_1.0.0.zip",
            category: Factorix::Types::Category.for("content")
          }
        ]

        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive_messages(nodes: [node_a], topological_order: [mod_a])
        allow(command).to receive(:plan_installation).and_return(install_targets)
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(false)
      end

      context "when user confirms" do
        before do
          allow($stdin).to receive(:gets).and_return("y\n")
        end

        it "installs the MOD" do
          capture_stdout { command.call(mod_specs: ["mod-a"]) }
          expect(mod_list).to have_received(:add).with(mod_a, enabled: true)
        end
      end

      context "when user declines" do
        before do
          allow($stdin).to receive(:gets).and_return("n\n")
        end

        it "does not install the MOD" do
          capture_stdout { command.call(mod_specs: ["mod-a"]) }
          expect(mod_list).not_to have_received(:add)
        end
      end
    end

    context "when game is running" do
      before do
        allow(runtime).to receive(:running?).and_return(true)
      end

      it "raises GameRunningError" do
        expect { command.call(mod_specs: ["mod-a"], yes: true) }
          .to raise_error(Factorix::GameRunningError, /Cannot perform this operation while Factorio is running/)
      end
    end
  end
end
