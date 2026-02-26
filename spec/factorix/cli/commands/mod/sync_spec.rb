# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::CLI::Commands::MOD::Sync do
  let(:command) do
    Factorix::CLI::Commands::MOD::Sync.new(
      runtime:,
      logger:
    )
  end

  let(:runtime) { instance_double(Factorix::Runtime::Base) }
  let(:portal) { instance_double(Factorix::Portal) }
  let(:logger) { instance_double(Dry::Logger::Dispatcher) }
  let(:save_file_path) { Pathname("spec/fixtures/test-save.zip") }
  let(:mod_dir) { Pathname("/tmp/mods") }
  let(:mod_list_path) { Pathname("/tmp/mod-list.json") }
  let(:mod_settings_path) { Pathname("/tmp/mod-settings.dat") }

  let(:game_version) { Factorix::GameVersion.from_string("2.0.72") }
  let(:mod_settings) do
    Factorix::MODSettings.new(
      game_version,
      Factorix::MODSettings::VALID_SECTIONS.to_h {|section_name|
        [section_name, Factorix::MODSettings::Section.new(section_name)]
      }
    )
  end
  let(:base_mod_version) { Factorix::MODVersion.from_string("2.0.72") }

  let(:save_data) do
    mods = {
      "base" => Factorix::MODState[enabled: true, version: base_mod_version],
      "test-mod" => Factorix::MODState[enabled: true, version: Factorix::MODVersion.from_string("1.0.0")]
    }
    startup_settings = Factorix::MODSettings::Section.new("startup")
    Factorix::SaveFile[version: game_version, mods:, startup_settings:]
  end

  let(:mod_list) { Factorix::MODList.new }
  let(:graph) { instance_double(Factorix::Dependency::Graph) }

  let(:base_info) do
    Factorix::InfoJSON[
      name: "base",
      version: base_mod_version,
      title: "Base MOD",
      author: "Wube",
      description: "Base game",
      factorio_version: "2.0",
      dependencies: []
    ]
  end

  let(:test_mod_info) do
    Factorix::InfoJSON[
      name: "test-mod",
      version: Factorix::MODVersion.from_string("1.0.0"),
      title: "Test MOD",
      author: "Test Author",
      description: "Test description",
      factorio_version: "2.0",
      dependencies: []
    ]
  end

  let(:installed_mods) do
    [
      Factorix::InstalledMOD[
        mod: Factorix::MOD[name: "base"],
        version: base_mod_version,
        form: Factorix::InstalledMOD::DIRECTORY_FORM,
        path: Pathname("/path/to/base"),
        info: base_info
      ],
      Factorix::InstalledMOD[
        mod: Factorix::MOD[name: "test-mod"],
        version: Factorix::MODVersion.from_string("1.0.0"),
        form: Factorix::InstalledMOD::ZIP_FORM,
        path: Pathname("/path/to/test-mod_1.0.0.zip"),
        info: test_mod_info
      ]
    ]
  end

  before do
    allow(runtime).to receive_messages(running?: false, mod_dir:, mod_list_path:, mod_settings_path:)
    allow(Factorix::SaveFile).to receive(:load).and_return(save_data)
    allow(Factorix::MODList).to receive(:load).and_return(mod_list)
    allow(Factorix::InstalledMOD).to receive(:all).and_return(installed_mods)
    allow(Factorix::Dependency::Graph).to receive(:from_installed_mods).and_return(graph)
    allow(graph).to receive_messages(edges_from: [], edges_to: [])
    allow(mod_list).to receive(:save)
    allow(mod_dir).to receive(:exist?).and_return(true)
    allow(logger).to receive(:debug)

    allow(Factorix::MODSettings).to receive_messages(load: mod_settings, new: mod_settings)
    allow(mod_settings).to receive(:save)
    allow(mod_settings_path).to receive(:exist?).and_return(true)
    allow(mod_settings_path).to receive(:rename)

    allow(command).to receive(:confirm?).and_return(true)
  end

  describe "#call" do
    context "when mod-list.json is already in sync with the save file" do
      before do
        mod_list.add(Factorix::MOD[name: "base"], enabled: true, version: base_mod_version)
        mod_list.add(Factorix::MOD[name: "test-mod"], enabled: true, version: Factorix::MODVersion.from_string("1.0.0"))
      end

      it "saves mod-list.json without asking for confirmation" do
        run_command(command, %W[#{save_file_path}])

        expect(command).not_to have_received(:confirm?)
        expect(mod_list).to have_received(:save).with(no_args)
      end
    end

    context "when there are enabled MODs not listed in the save file" do
      before do
        mod_list.add(Factorix::MOD[name: "base"], enabled: true, version: base_mod_version)
        mod_list.add(Factorix::MOD[name: "test-mod"], enabled: true, version: Factorix::MODVersion.from_string("1.0.0"))
        mod_list.add(Factorix::MOD[name: "extra-mod"], enabled: true)
        mod_list.add(Factorix::MOD[name: "space-age"], enabled: true)
      end

      it "asks for confirmation exactly once before applying changes" do
        run_command(command, %W[#{save_file_path}])

        expect(command).to have_received(:confirm?).once
      end

      it "disables unlisted regular and expansion MODs by default" do
        run_command(command, %W[#{save_file_path}])

        expect(mod_list.enabled?(Factorix::MOD[name: "extra-mod"])).to be false
        expect(mod_list.enabled?(Factorix::MOD[name: "space-age"])).to be false
      end

      it "keeps unlisted MODs enabled when --keep-unlisted is given" do
        run_command(command, %W[--keep-unlisted #{save_file_path}])

        expect(mod_list.enabled?(Factorix::MOD[name: "extra-mod"])).to be true
        expect(mod_list.enabled?(Factorix::MOD[name: "space-age"])).to be true
      end

      context "when user declines confirmation" do
        before do
          allow(command).to receive(:confirm?).and_return(false)
        end

        it "does not save mod-list.json" do
          run_command(command, %W[#{save_file_path}])

          expect(mod_list).not_to have_received(:save)
        end

        it "does not update mod-settings.dat" do
          run_command(command, %W[#{save_file_path}])

          expect(mod_settings).not_to have_received(:save)
        end
      end
    end

    context "when there are MODs to install and user declines confirmation" do
      let(:fake_release) do
        instance_double(
          Factorix::API::Release,
          version: Factorix::MODVersion.from_string("2.0.0"),
          file_name: "new-mod_2.0.0.zip"
        )
      end

      before do
        fake_targets = [{
          mod: Factorix::MOD[name: "new-mod"],
          release: fake_release,
          output_path: mod_dir / "new-mod_2.0.0.zip"
        }]
        allow(command).to receive(:execute_installation)
        allow(command).to receive_messages(find_mods_to_install: {"new-mod" => nil}, plan_installation: fake_targets, confirm?: false)
      end

      it "does not install MODs" do
        run_command(command, %W[#{save_file_path}])

        expect(command).not_to have_received(:execute_installation)
      end

      it "does not save mod-list.json" do
        run_command(command, %W[#{save_file_path}])

        expect(mod_list).not_to have_received(:save)
      end

      it "does not update mod-settings.dat" do
        run_command(command, %W[#{save_file_path}])

        expect(mod_settings).not_to have_received(:save)
      end
    end
  end
end
