# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::List do
  let(:runtime) do
    instance_double(
      Factorix::Runtime::Base,
      factorix_config_path: Pathname("/tmp/factorix/config.rb"),
      mod_list_path: Pathname("/fake/path/mod-list.json"),
      mod_dir: Pathname("/fake/path/mods"),
      data_dir: Pathname("/fake/path/data"),
      running?: false
    )
  end
  let(:logger) { instance_double(Dry::Logger::Dispatcher, debug: nil) }
  let(:mod_portal_api) { instance_double(Factorix::API::MODPortalAPI) }
  let(:command) { Factorix::CLI::Commands::MOD::List.new(runtime:, logger:, mod_portal_api:) }
  let(:mod_list) { instance_double(Factorix::MODList) }

  let(:base_mod) { Factorix::MOD[name: "base"] }
  let(:space_age_mod) { Factorix::MOD[name: "space-age"] }
  let(:quality_mod) { Factorix::MOD[name: "quality"] }
  let(:custom_mod) { Factorix::MOD[name: "custom-mod"] }
  let(:another_mod) { Factorix::MOD[name: "another-mod"] }

  let(:version_2_0_28) { Factorix::MODVersion.from_string("2.0.28") }
  let(:version_1_0_0) { Factorix::MODVersion.from_string("1.0.0") }
  let(:version_0_5_0) { Factorix::MODVersion.from_string("0.5.0") }

  let(:base_installed) do
    instance_double(Factorix::InstalledMOD, mod: base_mod, version: version_2_0_28)
  end
  let(:space_age_installed) do
    instance_double(Factorix::InstalledMOD, mod: space_age_mod, version: version_2_0_28)
  end
  let(:quality_installed) do
    instance_double(Factorix::InstalledMOD, mod: quality_mod, version: version_2_0_28)
  end
  let(:custom_installed) do
    instance_double(Factorix::InstalledMOD, mod: custom_mod, version: version_1_0_0)
  end
  let(:another_installed) do
    instance_double(Factorix::InstalledMOD, mod: another_mod, version: version_0_5_0)
  end

  before do
    allow(Factorix::Application).to receive(:load_config)
    allow(Factorix::MODList).to receive(:load).and_return(mod_list)
  end

  describe "#call" do
    context "with no MODs installed" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([])
        allow(mod_list).to receive(:exist?).and_return(false)
      end

      it "displays 'No MOD(s) found'" do
        output = capture_stdout { command.call(enabled: false, disabled: false, errors: false, outdated: false, json: false) }
        expect(output).to include("No MOD(s) found")
      end
    end

    context "with MODs installed" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([
          base_installed, space_age_installed, quality_installed, custom_installed, another_installed
        ])
        allow(mod_list).to receive(:enabled?).with(base_mod).and_return(true)
        allow(mod_list).to receive(:enabled?).with(space_age_mod).and_return(true)
        allow(mod_list).to receive(:enabled?).with(quality_mod).and_return(true)
        allow(mod_list).to receive(:enabled?).with(custom_mod).and_return(true)
        allow(mod_list).to receive(:enabled?).with(another_mod).and_return(false)
        allow(mod_list).to receive_messages(exist?: true, version: nil)
      end

      it "includes base and expansion MODs" do
        output = capture_stdout { command.call(enabled: false, disabled: false, errors: false, outdated: false, json: false) }
        expect(output).to include("base")
        expect(output).to include("space-age")
        expect(output).to include("quality")
        expect(output).to include("custom-mod")
        expect(output).to include("another-mod")
      end

      it "displays table header" do
        output = capture_stdout { command.call(enabled: false, disabled: false, errors: false, outdated: false, json: false) }
        expect(output).to include("NAME")
        expect(output).to include("VERSION")
        expect(output).to include("STATUS")
      end

      it "shows enabled status" do
        output = capture_stdout { command.call(enabled: false, disabled: false, errors: false, outdated: false, json: false) }
        expect(output).to match(/custom-mod.*enabled/)
        expect(output).to match(/another-mod.*disabled/)
      end

      it "sorts base first, then expansions, then others alphabetically" do
        output = capture_stdout { command.call(enabled: false, disabled: false, errors: false, outdated: false, json: false) }
        lines = output.lines.filter_map {|line| (stripped = line.strip).empty? ? nil : stripped }
        # Skip header line and summary line (last line)
        data_lines = lines[1...-1]
        mod_names = data_lines.map {|line| line.split.first }
        # base first, then expansions (alphabetically), then others (alphabetically)
        expect(mod_names).to eq(%w[base quality space-age another-mod custom-mod])
      end
    end

    context "with --enabled option" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([custom_installed, another_installed])
        allow(mod_list).to receive(:enabled?).with(custom_mod).and_return(true)
        allow(mod_list).to receive(:enabled?).with(another_mod).and_return(false)
        allow(mod_list).to receive_messages(exist?: true, version: nil)
      end

      it "shows only enabled MODs" do
        output = capture_stdout { command.call(enabled: true, disabled: false, errors: false, outdated: false, json: false) }
        expect(output).to include("custom-mod")
        expect(output).not_to include("another-mod")
      end
    end

    context "with --disabled option" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([custom_installed, another_installed])
        allow(mod_list).to receive(:enabled?).with(custom_mod).and_return(true)
        allow(mod_list).to receive(:enabled?).with(another_mod).and_return(false)
        allow(mod_list).to receive_messages(exist?: true, version: nil)
      end

      it "shows only disabled MODs" do
        output = capture_stdout { command.call(enabled: false, disabled: true, errors: false, outdated: false, json: false) }
        expect(output).not_to include("custom-mod")
        expect(output).to include("another-mod")
      end

      context "when no MODs match the filter" do
        before do
          allow(Factorix::InstalledMOD).to receive(:all).and_return([custom_installed])
          allow(mod_list).to receive(:enabled?).with(custom_mod).and_return(true)
          allow(mod_list).to receive_messages(exist?: true, version: nil)
        end

        it "displays 'No MOD(s) match the specified criteria'" do
          output = capture_stdout { command.call(enabled: false, disabled: true, errors: false, outdated: false, json: false) }
          expect(output).to include("No MOD(s) match the specified criteria")
          expect(output).not_to include("No MOD(s) found")
        end
      end
    end

    context "with --enabled option and no matches" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([another_installed])
        allow(mod_list).to receive(:enabled?).with(another_mod).and_return(false)
        allow(mod_list).to receive_messages(exist?: true, version: nil)
      end

      it "displays 'No MOD(s) match the specified criteria'" do
        output = capture_stdout { command.call(enabled: true, disabled: false, errors: false, outdated: false, json: false) }
        expect(output).to include("No MOD(s) match the specified criteria")
        expect(output).not_to include("No MOD(s) found")
      end
    end

    context "with --json option" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([custom_installed])
        allow(mod_list).to receive(:enabled?).with(custom_mod).and_return(true)
        allow(mod_list).to receive_messages(exist?: true, version: nil)
      end

      it "outputs valid JSON" do
        output = capture_stdout { command.call(enabled: false, disabled: false, errors: false, outdated: false, json: true) }
        json = JSON.parse(output)
        expect(json).to be_an(Array)
        expect(json.first).to include("name" => "custom-mod", "version" => "1.0.0", "enabled" => true)
      end
    end

    context "with --outdated option" do
      let(:version_2_0_0) { Factorix::MODVersion.from_string("2.0.0") }

      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([custom_installed, another_installed])
        allow(mod_list).to receive(:enabled?).with(custom_mod).and_return(true)
        allow(mod_list).to receive(:enabled?).with(another_mod).and_return(true)
        allow(mod_list).to receive_messages(exist?: true, version: nil)

        # custom-mod has update available (1.0.0 -> 2.0.0)
        allow(mod_portal_api).to receive(:get_mod).with("custom-mod").and_return({
          releases: [{version: "2.0.0"}, {version: "1.0.0"}]
        })
        # another-mod is up to date
        allow(mod_portal_api).to receive(:get_mod).with("another-mod").and_return({
          releases: [{version: "0.5.0"}]
        })

        # Stub Progress::Presenter to avoid tty-progressbar issues in parallel test environment
        presenter = instance_double(Factorix::Progress::Presenter, start: nil, update: nil, finish: nil)
        allow(Factorix::Progress::Presenter).to receive(:new).and_return(presenter)
      end

      it "shows only MODs with available updates" do
        output = capture_stdout { command.call(enabled: false, disabled: false, errors: false, outdated: true, json: false) }
        expect(output).to include("custom-mod")
        expect(output).not_to include("another-mod")
      end

      it "displays LATEST column with new version" do
        output = capture_stdout { command.call(enabled: false, disabled: false, errors: false, outdated: true, json: false) }
        expect(output).to include("LATEST")
        expect(output).to include("2.0.0")
      end

      context "when no MODs have available updates" do
        before do
          # Both MODs are up to date
          allow(mod_portal_api).to receive(:get_mod).with("custom-mod").and_return({
            releases: [{version: "1.0.0"}]
          })
          allow(mod_portal_api).to receive(:get_mod).with("another-mod").and_return({
            releases: [{version: "0.5.0"}]
          })
        end

        it "displays 'No MOD(s) match the specified criteria'" do
          output = capture_stdout { command.call(enabled: false, disabled: false, errors: false, outdated: true, json: false) }
          expect(output).to include("No MOD(s) match the specified criteria")
          expect(output).not_to include("No MOD(s) found")
        end
      end
    end

    context "with conflicting filter options" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([])
      end

      it "raises ArgumentError when combining --enabled and --disabled" do
        expect {
          capture_stdout { command.call(enabled: true, disabled: true, errors: false, outdated: false, json: false) }
        }.to raise_error(ArgumentError, /Cannot combine/)
      end

      it "raises ArgumentError when combining --enabled and --outdated" do
        expect {
          capture_stdout { command.call(enabled: true, disabled: false, errors: false, outdated: true, json: false) }
        }.to raise_error(ArgumentError, /Cannot combine/)
      end
    end

    context "when MOD not in mod-list.json" do
      before do
        allow(Factorix::InstalledMOD).to receive(:all).and_return([custom_installed])
        allow(mod_list).to receive(:exist?).with(custom_mod).and_return(false)
      end

      it "shows MOD as disabled" do
        output = capture_stdout { command.call(enabled: false, disabled: false, errors: false, outdated: false, json: false) }
        expect(output).to match(/custom-mod.*disabled/)
      end
    end
  end
end
