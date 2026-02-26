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

    # Create a mock MODSettings if needed
    mod_settings = Factorix::MODSettings.new(
      game_version,
      Factorix::MODSettings::VALID_SECTIONS.to_h {|section_name|
        [section_name, Factorix::MODSettings::Section.new(section_name)]
      }
    )
    allow(Factorix::MODSettings).to receive_messages(load: mod_settings, new: mod_settings)
    allow(mod_settings).to receive(:save)
    allow(mod_settings_path).to receive(:exist?).and_return(true)
    allow(mod_settings_path).to receive(:rename)

    # Stub confirmation to always return true
    allow(command).to receive(:confirm?).and_return(true)
  end

  describe "#call" do
    context "when all MODs from save file are already installed" do
      before do
        mod_list.add(Factorix::MOD[name: "base"], enabled: true, version: base_mod_version)
        mod_list.add(Factorix::MOD[name: "test-mod"], enabled: true, version: Factorix::MODVersion.from_string("1.0.0"))
      end

      it "updates mod-list.json" do
        run_command(command, %W[#{save_file_path}])

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
    end
  end
end
