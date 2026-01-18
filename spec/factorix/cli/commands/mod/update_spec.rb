# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Update do
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
  let(:logger) { instance_double(Dry::Logger::Dispatcher, debug: nil, warn: nil) }
  let(:portal) { instance_spy(Factorix::Portal) }
  let(:command) do
    Factorix::CLI::Commands::MOD::Update.new(
      runtime:,
      logger:,
      portal:
    )
  end
  let(:mod_list_path) { Pathname("/fake/path/mod-list.json") }
  let(:mod_dir) { Pathname("/fake/path/mods") }
  let(:data_dir) { Pathname("/fake/path/data") }
  let(:mod_list) { instance_spy(Factorix::MODList) }

  # Test MODs
  let(:mod_a) { Factorix::MOD[name: "mod-a"] }
  let(:base_mod) { Factorix::MOD[name: "base"] }
  let(:space_age_mod) { Factorix::MOD[name: "space-age"] }

  # Versions
  let(:version_1_0_0) { Factorix::MODVersion.from_string("1.0.0") }
  let(:version_2_0_0) { Factorix::MODVersion.from_string("2.0.0") }

  # Installed MODs
  let(:installed_mod_a) do
    instance_double(Factorix::InstalledMOD, mod: mod_a, version: version_1_0_0)
  end

  # Test MODInfo
  let(:mod_info_a) do
    instance_double(
      Factorix::API::MODInfo,
      name: "mod-a",
      category: Factorix::API::Category.for("content"),
      releases: [release_a_v1, release_a_v2]
    )
  end

  # Test Releases
  let(:release_a_v1) do
    instance_double(
      Factorix::API::Release,
      version: version_1_0_0,
      file_name: "mod-a_1.0.0.zip",
      released_at: Time.new(2024, 1, 1)
    )
  end
  let(:release_a_v2) do
    instance_double(
      Factorix::API::Release,
      version: version_2_0_0,
      file_name: "mod-a_2.0.0.zip",
      released_at: Time.new(2024, 6, 1)
    )
  end

  before do
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:runtime).and_return(runtime)
    allow(Factorix::Container).to receive(:[]).with(:logger).and_return(logger)
    allow(Factorix::Container).to receive(:[]).with(:portal).and_return(portal)

    allow(Factorix::Container).to receive(:load_config)

    allow(Factorix::MODList).to receive(:load).and_return(mod_list)
    allow(mod_list).to receive_messages(save: nil, exist?: true, enabled?: true, remove: nil, add: nil)
    allow(mod_dir).to receive(:/).and_return(Pathname("/fake/path/mods/mod-a_2.0.0.zip"))

    downloader = instance_double(Factorix::Transfer::Downloader)
    allow(downloader).to receive(:subscribe)
    allow(downloader).to receive(:unsubscribe)
    mod_download_api = instance_double(Factorix::API::MODDownloadAPI, downloader:)
    allow(portal).to receive_messages(get_mod_full: mod_info_a, mod_download_api:, download_mod: nil)

    # Simulate user confirmation
    allow(command).to receive(:confirm?).and_return(true)
  end

  describe "#call" do
    context "when MOD has available update" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a])
      end

      it "downloads and updates the MOD" do
        run_command(command, "mod-a", jobs: 1)

        expect(portal).to have_received(:download_mod)
        expect(mod_list).to have_received(:remove).with(mod_a)
        expect(mod_list).to have_received(:add).with(mod_a, enabled: true)
        expect(mod_list).to have_received(:save)
      end
    end

    context "when MOD is already up to date" do
      let(:installed_mod_a_latest) do
        instance_double(Factorix::InstalledMOD, mod: mod_a, version: version_2_0_0)
      end

      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a_latest])
      end

      it "does not perform any updates" do
        run_command(command, "mod-a", jobs: 1)

        expect(portal).not_to have_received(:download_mod)
      end
    end

    context "when no MOD names specified" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod_a])
      end

      it "updates all installed MODs" do
        run_command(command, jobs: 1)

        expect(portal).to have_received(:download_mod)
      end
    end

    context "when trying to update base MOD" do
      it "raises an error" do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([])

        expect {
          run_command(command, "base", jobs: 1)
        }.to raise_error(Factorix::Error, /Cannot update base MOD/)
      end
    end

    context "when trying to update expansion MOD" do
      it "raises an error" do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([])

        expect {
          run_command(command, "space-age", jobs: 1)
        }.to raise_error(Factorix::Error, /Cannot update expansion MOD/)
      end
    end

    context "when no MODs are installed" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([])
      end

      it "does not perform any updates" do
        run_command(command, jobs: 1)

        expect(portal).not_to have_received(:download_mod)
      end
    end
  end
end
