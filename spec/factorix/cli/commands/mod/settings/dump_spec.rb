# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::CLI::Commands::MOD::Settings::Dump do
  let(:command) do
    Factorix::CLI::Commands::MOD::Settings::Dump.new(
      runtime:
    )
  end

  let(:runtime) { instance_double(Factorix::Runtime::Base) }
  let(:default_settings_path) { Pathname("/default/mod-settings.dat") }
  let(:game_version) { Factorix::GameVersion.from_string("1.1.0-42") }
  let(:startup_section) do
    section = Factorix::MODSettings::Section.new("startup")
    section["string-value"] = "test"
    section["bool-value"] = true
    section["float-value"] = 1.5
    section["signed-int"] = Factorix::SerDes::SignedInteger.new(42)
    section["unsigned-int"] = Factorix::SerDes::UnsignedInteger.new(100)
    section
  end
  let(:sections) { {"startup" => startup_section} }
  let(:settings) { Factorix::MODSettings.new(game_version, sections) }

  before do
    allow(runtime).to receive(:mod_settings_path).and_return(default_settings_path)
    allow(Factorix::MODSettings).to receive(:load).and_return(settings)
  end

  describe "#call" do
    context "with default options" do
      it "dumps to JSON format to stdout" do
        result = run_command(command)
        expect(result.stdout).to match(/"game_version": "1.1.0-42"/)
        expect(result.stdout).to match(/"startup":/)
        expect(result.stdout).to match(/"string-value": "test"/)
      end

      it "loads from default path" do
        run_command(command)

        expect(Factorix::MODSettings).to have_received(:load).with(default_settings_path)
      end
    end

    context "with custom settings file" do
      it "loads from specified file" do
        settings_path = Pathname("/path/to/mod-settings.dat")
        allow(Factorix::MODSettings).to receive(:load).with(settings_path).and_return(settings)

        result = run_command(command, settings_path.to_s)
        expect(result.stdout).to match(/game_version/)

        expect(Factorix::MODSettings).to have_received(:load).with(settings_path)
      end
    end

    context "with output file" do
      let(:output_file) { Tempfile.new(["test-output", ".json"]) }

      after do
        output_file.close
        output_file.unlink
      end

      it "writes to specified file" do
        run_command(command, output: output_file.path)

        content = File.read(output_file.path)
        expect(content).to match(/"game_version": "1.1.0-42"/)
      end

      it "does not output to stdout" do
        result = run_command(command, output: output_file.path)
        expect(result.stdout).to be_empty
      end
    end
  end
end
