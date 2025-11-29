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
  let(:game_version) { Factorix::Types::GameVersion.from_string("1.1.0-42") }
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
        expect { command.call }.to output(/"game_version": "1.1.0-42"/).to_stdout
        expect { command.call }.to output(/"startup":/).to_stdout
        expect { command.call }.to output(/"string-value": "test"/).to_stdout
      end

      it "loads from default path" do
        expect { command.call }.to output.to_stdout

        expect(Factorix::MODSettings).to have_received(:load).with(default_settings_path)
      end
    end

    context "with custom settings file" do
      it "loads from specified file" do
        settings_path = Pathname("/path/to/mod-settings.dat")
        allow(Factorix::MODSettings).to receive(:load).with(settings_path).and_return(settings)

        expect { command.call(settings_file: settings_path.to_s) }.to output(/game_version/).to_stdout

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
        command.call(output: output_file.path)

        content = File.read(output_file.path)
        expect(content).to match(/"game_version": "1.1.0-42"/)
      end

      it "does not output to stdout" do
        expect { command.call(output: output_file.path) }.not_to output.to_stdout
      end
    end
  end
end
