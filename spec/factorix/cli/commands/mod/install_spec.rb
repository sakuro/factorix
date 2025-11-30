# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Install do
  include_context "with suppressed output"
  include_context "with suppressed progress bar"

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
  let(:portal) { instance_spy(Factorix::Portal) }
  let(:command) do
    Factorix::CLI::Commands::MOD::Install.new(
      runtime:,
      logger:,
      portal:
    )
  end
  let(:mod_list_path) { Pathname("/fake/path/mod-list.json") }
  let(:mod_dir) { Pathname("/fake/path/mods") }
  let(:data_dir) { Pathname("/fake/path/data") }
  let(:mod_list) { instance_spy(Factorix::MODList) }
  let(:graph) { instance_spy(Factorix::Dependency::Graph) }

  # Test MODs
  let(:mod_a) { Factorix::MOD[name: "mod-a"] }
  let(:mod_b) { Factorix::MOD[name: "mod-b"] }

  # Test MODInfo
  let(:mod_info_a) do
    instance_double(
      Factorix::API::MODInfo,
      name: "mod-a",
      category: Factorix::API::Category.for("content"),
      releases: [release_a]
    )
  end

  # Test Release
  let(:release_a) do
    instance_double(
      Factorix::API::Release,
      version: Factorix::MODVersion.from_string("1.0.0"),
      file_name: "mod-a_1.0.0.zip",
      info_json: {dependencies: []},
      released_at: Time.now
    )
  end

  before do
    allow(Factorix::Application).to receive(:[]).and_call_original
    allow(Factorix::Application).to receive(:[]).with(:runtime).and_return(runtime)
    allow(Factorix::Application).to receive(:[]).with(:logger).and_return(logger)
    allow(Factorix::Application).to receive(:[]).with(:portal).and_return(portal)

    allow(Factorix::Application).to receive(:load_config)

    allow(Factorix::MODList).to receive(:load).and_return(mod_list)
    allow(mod_list).to receive(:save)
    allow(mod_list).to receive(:add)
    allow(mod_list).to receive(:enable)
    allow(mod_list).to receive(:exist?)
    allow(mod_list).to receive(:enabled?)
    allow(Factorix::InstalledMOD).to receive(:all).and_return([])
    allow(Factorix::Dependency::Graph::Builder).to receive(:build).and_return(graph)
    allow(graph).to receive(:add_uninstalled_mod)
    allow(graph).to receive_messages(nodes: [], node?: false, node: nil, edges_from: [], cyclic?: false)
    allow(command).to receive(:load_current_state).and_return([graph, mod_list, []])
    allow(mod_dir).to receive_messages(exist?: true, "/": Pathname("/fake/path/mods/mod-a_1.0.0.zip"))
    allow(portal).to receive(:download_mod)
    allow(Factorix::Application).to receive(:[]).with(:portal).and_return(portal)

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
          version: Factorix::MODVersion.from_string("1.0.0"),
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
            category: Factorix::API::Category.for("content")
          }
        ]

        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:nodes).and_return([node_a])
        allow(command).to receive(:plan_installation).and_return(install_targets)
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(false)
      end

      it "downloads the MOD" do
        command.call(mod_specs: ["mod-a"], yes: true)
        expect(portal).to have_received(:download_mod)
      end

      it "adds the MOD to mod-list.json" do
        command.call(mod_specs: ["mod-a"], yes: true)
        expect(mod_list).to have_received(:add).with(mod_a, enabled: true)
      end

      it "saves mod-list.json" do
        command.call(mod_specs: ["mod-a"], yes: true)
        expect(mod_list).to have_received(:save).with(mod_list_path)
      end
    end

    context "when installing a MOD with dependencies" do
      let(:node_a) do
        instance_double(
          Factorix::Dependency::Node,
          mod: mod_a,
          version: Factorix::MODVersion.from_string("1.0.0"),
          operation: :install
        )
      end

      let(:node_b) do
        instance_double(
          Factorix::Dependency::Node,
          mod: mod_b,
          version: Factorix::MODVersion.from_string("1.0.0"),
          operation: :install
        )
      end

      let(:mod_info_b) do
        instance_double(
          Factorix::API::MODInfo,
          name: "mod-b",
          category: Factorix::API::Category.for("internal"),
          releases: [release_b]
        )
      end

      let(:release_b) do
        instance_double(
          Factorix::API::Release,
          version: Factorix::MODVersion.from_string("1.0.0"),
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
            category: Factorix::API::Category.for("internal")
          },
          {
            mod: mod_a,
            mod_info: mod_info_a,
            release: release_a,
            output_path: mod_dir / "mod-a_1.0.0.zip",
            category: Factorix::API::Category.for("content")
          }
        ]

        allow(graph).to receive(:nodes).and_return([node_a, node_b])
        allow(command).to receive(:plan_installation).and_return(install_targets)
        allow(mod_list).to receive(:exist?).and_return(false)
      end

      it "downloads both MODs in dependency order" do
        command.call(mod_specs: ["mod-a"], yes: true)
        expect(portal).to have_received(:download_mod).twice
      end
    end

    context "when MOD is already installed and enabled" do
      before do
        # Empty install targets
        allow(graph).to receive(:nodes).and_return([])
      end

      it "does not download anything" do
        command.call(mod_specs: ["mod-a"], yes: true)
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
        command.call(mod_specs: ["mod-a@1.0.0"], yes: true)
        expect(portal).to have_received(:get_mod_full).with("mod-a")
      end

      it "accepts name@latest format" do
        allow(graph).to receive(:nodes).and_return([])
        command.call(mod_specs: ["mod-a@latest"], yes: true)
        expect(portal).to have_received(:get_mod_full).with("mod-a")
      end
    end

    context "with confirmation prompt" do
      let(:node_a) do
        instance_double(
          Factorix::Dependency::Node,
          mod: mod_a,
          version: Factorix::MODVersion.from_string("1.0.0"),
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
            category: Factorix::API::Category.for("content")
          }
        ]

        allow(graph).to receive(:node?).with(mod_a).and_return(true)
        allow(graph).to receive(:node).with(mod_a).and_return(node_a)
        allow(graph).to receive(:nodes).and_return([node_a])
        allow(command).to receive(:plan_installation).and_return(install_targets)
        allow(mod_list).to receive(:exist?).with(mod_a).and_return(false)
      end

      context "when user confirms" do
        before do
          allow($stdin).to receive(:gets).and_return("y\n")
        end

        it "installs the MOD" do
          command.call(mod_specs: ["mod-a"])
          expect(mod_list).to have_received(:add).with(mod_a, enabled: true)
        end
      end

      context "when user declines" do
        before do
          allow($stdin).to receive(:gets).and_return("n\n")
        end

        it "does not install the MOD" do
          command.call(mod_specs: ["mod-a"])
          expect(mod_list).not_to have_received(:add)
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

      it "raises GameRunningError" do
        expect { command.call(mod_specs: ["mod-a"], yes: true) }
          .to raise_error(Factorix::GameRunningError, /Cannot perform this operation while Factorio is running/)
      end
    end
  end
end
