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
    context "when mod-list.json is already in sync with the save file and startup settings have not changed" do
      before do
        mod_list.add(Factorix::MOD[name: "base"], enabled: true, version: base_mod_version)
        mod_list.add(Factorix::MOD[name: "test-mod"], enabled: true, version: Factorix::MODVersion.from_string("1.0.0"))
      end

      it "does not ask for confirmation" do
        run_command(command, %W[#{save_file_path}])

        expect(command).not_to have_received(:confirm?)
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

    describe "--strict-version" do
      let(:save_version) { Factorix::MODVersion.from_string("1.0.0") }
      let(:newer_version) { Factorix::MODVersion.from_string("1.1.0") }
      let(:older_version) { Factorix::MODVersion.from_string("0.9.0") }

      let(:newer_mod_path) { Pathname("/tmp/mods/test-mod_1.1.0.zip") }
      let(:newer_installed_mod) do
        Factorix::InstalledMOD[
          mod: Factorix::MOD[name: "test-mod"],
          version: newer_version,
          form: Factorix::InstalledMOD::ZIP_FORM,
          path: newer_mod_path,
          info: Factorix::InfoJSON[
            name: "test-mod",
            version: newer_version,
            title: "Test MOD",
            author: "Test Author",
            description: "Test description",
            factorio_version: "2.0",
            dependencies: []
          ]
        ]
      end

      let(:older_installed_mod) do
        Factorix::InstalledMOD[
          mod: Factorix::MOD[name: "test-mod"],
          version: older_version,
          form: Factorix::InstalledMOD::ZIP_FORM,
          path: Pathname("/tmp/mods/test-mod_0.9.0.zip"),
          info: Factorix::InfoJSON[
            name: "test-mod",
            version: older_version,
            title: "Test MOD",
            author: "Test Author",
            description: "Test description",
            factorio_version: "2.0",
            dependencies: []
          ]
        ]
      end

      context "when already in sync at exact version" do
        before do
          mod_list.add(Factorix::MOD[name: "base"], enabled: true, version: base_mod_version)
          mod_list.add(Factorix::MOD[name: "test-mod"], enabled: true, version: save_version)
        end

        it "does not ask for confirmation" do
          run_command(command, %W[--strict-version #{save_file_path}])

          expect(command).not_to have_received(:confirm?)
        end

        it "does not save mod-list.json" do
          run_command(command, %W[--strict-version #{save_file_path}])

          expect(mod_list).not_to have_received(:save)
        end
      end

      context "when mod-list.json has no version recorded but installed version matches save version" do
        before do
          # Version not recorded (nil) - happens after a non-strict sync
          mod_list.add(Factorix::MOD[name: "base"], enabled: true, version: base_mod_version)
          mod_list.add(Factorix::MOD[name: "test-mod"], enabled: true)
        end

        it "does not ask for confirmation" do
          run_command(command, %W[--strict-version #{save_file_path}])

          expect(command).not_to have_received(:confirm?)
        end

        it "does not save mod-list.json" do
          run_command(command, %W[--strict-version #{save_file_path}])

          expect(mod_list).not_to have_received(:save)
        end
      end

      context "when a newer version is installed" do
        before do
          mod_list.add(Factorix::MOD[name: "base"], enabled: true, version: base_mod_version)
          mod_list.add(Factorix::MOD[name: "test-mod"], enabled: true, version: newer_version)
          allow(Factorix::InstalledMOD).to receive(:all).and_return([
            Factorix::InstalledMOD[
              mod: Factorix::MOD[name: "base"],
              version: base_mod_version,
              form: Factorix::InstalledMOD::DIRECTORY_FORM,
              path: Pathname("/path/to/base"),
              info: base_info
            ],
            newer_installed_mod
          ])
          allow(command).to receive(:execute_deletions).and_call_original
          allow(newer_mod_path).to receive(:delete)
        end

        context "when also downloading the save version" do
          before do
            allow(command).to receive(:execute_installation)
            allow(command).to receive(:plan_installation).and_return([])
          end

          it "asks for confirmation" do
            run_command(command, %W[--strict-version #{save_file_path}])

            expect(command).to have_received(:confirm?).once
          end

          it "deletes the newer version zip" do
            run_command(command, %W[--strict-version #{save_file_path}])

            expect(newer_mod_path).to have_received(:delete)
          end

          it "records exact save version in mod-list.json" do
            run_command(command, %W[--strict-version #{save_file_path}])

            expect(mod_list.version(Factorix::MOD[name: "test-mod"])).to eq(save_version)
          end
        end
      end

      context "when an older version is installed" do
        before do
          mod_list.add(Factorix::MOD[name: "base"], enabled: true, version: base_mod_version)
          mod_list.add(Factorix::MOD[name: "test-mod"], enabled: true, version: older_version)
          allow(Factorix::InstalledMOD).to receive(:all).and_return([
            Factorix::InstalledMOD[
              mod: Factorix::MOD[name: "base"],
              version: base_mod_version,
              form: Factorix::InstalledMOD::DIRECTORY_FORM,
              path: Pathname("/path/to/base"),
              info: base_info
            ],
            older_installed_mod
          ])
          allow(command).to receive(:execute_installation)
          allow(command).to receive(:plan_installation).and_return([])
        end

        it "does not delete the older version zip" do
          allow(older_installed_mod.path).to receive(:delete)

          run_command(command, %W[--strict-version #{save_file_path}])

          expect(older_installed_mod.path).not_to have_received(:delete)
        end

        it "records exact save version in mod-list.json" do
          run_command(command, %W[--strict-version #{save_file_path}])

          expect(mod_list.version(Factorix::MOD[name: "test-mod"])).to eq(save_version)
        end
      end

      context "when user declines confirmation" do
        before do
          mod_list.add(Factorix::MOD[name: "base"], enabled: true, version: base_mod_version)
          mod_list.add(Factorix::MOD[name: "test-mod"], enabled: true, version: newer_version)
          allow(Factorix::InstalledMOD).to receive(:all).and_return([
            Factorix::InstalledMOD[
              mod: Factorix::MOD[name: "base"],
              version: base_mod_version,
              form: Factorix::InstalledMOD::DIRECTORY_FORM,
              path: Pathname("/path/to/base"),
              info: base_info
            ],
            newer_installed_mod
          ])
          allow(command).to receive(:execute_deletions)
          allow(command).to receive(:execute_installation)
          allow(command).to receive_messages(confirm?: false, plan_installation: [])
          allow(newer_mod_path).to receive(:delete)
        end

        it "does not delete the newer version zip" do
          run_command(command, %W[--strict-version #{save_file_path}])

          expect(command).not_to have_received(:execute_deletions)
        end

        it "does not save mod-list.json" do
          run_command(command, %W[--strict-version #{save_file_path}])

          expect(mod_list).not_to have_received(:save)
        end
      end
    end
  end
end
