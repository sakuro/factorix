# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::CLI::Commands::MOD::Settings::Restore do
  subject(:command) do
    Factorix::CLI::Commands::MOD::Settings::Restore.new(
      json_converter: json_converter_double,
      toml_converter: toml_converter_double,
      runtime: runtime_double
    )
  end

  let(:json_converter_double) { instance_double(Factorix::MODSettings::JSONConverter) }
  let(:toml_converter_double) { instance_double(Factorix::MODSettings::TOMLConverter) }
  let(:runtime_double) { instance_double(Factorix::Runtime::Base) }
  let(:game_version) { Factorix::Types::GameVersion.from_string("1.1.0-42") }
  let(:startup_section) do
    section = Factorix::MODSettings::Section.new("startup")
    section["string-value"] = "test"
    section["bool-value"] = true
    section["float-value"] = 1.5
    section["int-value"] = Factorix::Types::SignedInteger.new(42)
    section
  end
  let(:sections) { {"startup" => startup_section} }
  let(:settings) { Factorix::MODSettings.new(game_version, sections) }
  let(:toml_string) do
    <<~TOML
      game_version = "1.1.0-42"

      [startup]
      string-value = "test"
      bool-value = true
      float-value = 1.5
      int-value = 42
    TOML
  end
  let(:json_string) do
    <<~JSON
      {
        "game_version": "1.1.0-42",
        "startup": {
          "string-value": "test",
          "bool-value": true,
          "float-value": 1.5,
          "int-value": 42
        }
      }
    JSON
  end

  before do
    allow(settings).to receive(:save)
    allow(runtime_double).to receive(:mod_settings_path).and_return(Pathname("/default/mod-settings.dat"))
  end

  describe "#call" do
    context "with TOML input file" do
      let(:input_file) { Tempfile.new(["input", ".toml"]) }
      let(:output_file) { Tempfile.new("mod-settings.dat") }
      let(:output_path) { Pathname(output_file.path) }

      before do
        allow(toml_converter_double).to receive(:convert_from).and_return(settings)
        input_file.write(toml_string)
        input_file.rewind
      end

      after do
        input_file.close
        input_file.unlink
        output_file.close
        output_file.unlink
      end

      it "loads from TOML file and saves settings" do
        command.call(input: input_file.path, settings_file: output_path.to_s)

        expect(toml_converter_double).to have_received(:convert_from).with(toml_string)
        expect(settings).to have_received(:save).with(to: output_path)
      end

      it "auto-detects format from extension" do
        command.call(input: input_file.path, settings_file: output_path.to_s)

        expect(toml_converter_double).to have_received(:convert_from)
      end
    end

    context "with JSON input file" do
      let(:input_file) { Tempfile.new(["input", ".json"]) }
      let(:output_file) { Tempfile.new("mod-settings.dat") }
      let(:output_path) { Pathname(output_file.path) }

      before do
        allow(json_converter_double).to receive(:convert_from).and_return(settings)
        input_file.write(json_string)
        input_file.rewind
      end

      after do
        input_file.close
        input_file.unlink
        output_file.close
        output_file.unlink
      end

      it "loads from JSON file and saves settings" do
        command.call(input: input_file.path, settings_file: output_path.to_s)

        expect(json_converter_double).to have_received(:convert_from).with(json_string)
        expect(settings).to have_received(:save).with(to: output_path)
      end

      it "auto-detects format from extension" do
        command.call(input: input_file.path, settings_file: output_path.to_s)

        expect(json_converter_double).to have_received(:convert_from)
      end
    end

    context "with explicit format option" do
      let(:input_file) { Tempfile.new(["input", ".txt"]) }
      let(:output_file) { Tempfile.new("mod-settings.dat") }
      let(:output_path) { Pathname(output_file.path) }

      before do
        allow(toml_converter_double).to receive(:convert_from).and_return(settings)
        input_file.write(toml_string)
        input_file.rewind
      end

      after do
        input_file.close
        input_file.unlink
        output_file.close
        output_file.unlink
      end

      it "uses specified format instead of auto-detection" do
        command.call(input: input_file.path, format: "toml", settings_file: output_path.to_s)

        expect(toml_converter_double).to have_received(:convert_from)
      end
    end

    context "with stdin input" do
      let(:output_file) { Tempfile.new("mod-settings.dat") }
      let(:output_path) { Pathname(output_file.path) }

      after do
        output_file.close
        output_file.unlink
      end

      before do
        allow(toml_converter_double).to receive(:convert_from).and_return(settings)
        allow($stdin).to receive(:read).and_return(toml_string)
      end

      it "reads from stdin when no input file specified" do
        command.call(format: "toml", settings_file: output_path.to_s)

        expect($stdin).to have_received(:read)
        expect(toml_converter_double).to have_received(:convert_from).with(toml_string)
        expect(settings).to have_received(:save).with(to: output_path)
      end

      it "raises error when format not specified" do
        expect { command.call(settings_file: output_path.to_s) }.to raise_error(ArgumentError, /--format option is required when reading from stdin/)
      end
    end

    context "with custom output file" do
      let(:input_file) { Tempfile.new(["input", ".toml"]) }
      let(:custom_output_file) { Tempfile.new("mod-settings.dat") }

      before do
        allow(toml_converter_double).to receive(:convert_from).and_return(settings)
        input_file.write(toml_string)
        input_file.rewind
      end

      after do
        input_file.close
        input_file.unlink
        custom_output_file.close
        custom_output_file.unlink
      end

      it "saves to specified output file" do
        command.call(input: input_file.path, settings_file: custom_output_file.path)

        expect(settings).to have_received(:save).with(to: Pathname(custom_output_file.path))
      end
    end

    context "with default output file" do
      let(:input_file) { Tempfile.new(["input", ".toml"]) }
      let(:default_path) { instance_double(Pathname, exist?: false) }

      before do
        allow(runtime_double).to receive(:mod_settings_path).and_return(default_path)
        allow(toml_converter_double).to receive(:convert_from).and_return(settings)
        input_file.write(toml_string)
        input_file.rewind
      end

      after do
        input_file.close
        input_file.unlink
      end

      it "saves to default path when settings_file not specified" do
        command.call(input: input_file.path)

        expect(settings).to have_received(:save).with(to: default_path)
      end
    end

    context "with backup" do
      let(:input_file) { Tempfile.new(["input", ".toml"]) }
      let(:output_file) { Tempfile.new("mod-settings.dat") }
      let(:output_path) { Pathname(output_file.path) }

      before do
        allow(toml_converter_double).to receive(:convert_from).and_return(settings)
        input_file.write(toml_string)
        input_file.rewind
        output_file.write("existing content")
        output_file.rewind
      end

      after do
        input_file.close
        input_file.unlink
        output_file.close
        output_file.unlink
        FileUtils.rm_f("#{output_file.path}.bak")
        FileUtils.rm_f("#{output_file.path}.old")
      end

      it "creates backup when output file exists" do
        command.call(input: input_file.path, settings_file: output_file.path)

        backup_file = "#{output_file.path}.bak"
        expect(File.exist?(backup_file)).to be true
        expect(File.read(backup_file)).to eq("existing content")
      end

      it "uses custom backup extension" do
        command.call(input: input_file.path, settings_file: output_file.path, backup_extension: ".old")

        backup_file = "#{output_file.path}.old"
        expect(File.exist?(backup_file)).to be true
        expect(File.read(backup_file)).to eq("existing content")
      end

      it "does not create backup when output file does not exist" do
        output_file.close
        output_file.unlink

        command.call(input: input_file.path, settings_file: output_file.path)

        backup_file = "#{output_file.path}.bak"
        expect(File.exist?(backup_file)).to be false
      end
    end

    context "with unknown extension" do
      let(:input_file) { Tempfile.new(["input", ".xyz"]) }
      let(:output_file) { Tempfile.new("mod-settings.dat") }
      let(:output_path) { Pathname(output_file.path) }

      before do
        input_file.write(toml_string)
        input_file.rewind
      end

      after do
        input_file.close
        input_file.unlink
        output_file.close
        output_file.unlink
      end

      it "raises error when format cannot be detected" do
        expect {
          command.call(input: input_file.path, settings_file: output_path.to_s)
        }.to raise_error(ArgumentError, /Unknown format/)
      end
    end

    context "with unknown format" do
      let(:input_file) { Tempfile.new(["input", ".toml"]) }
      let(:output_file) { Tempfile.new("mod-settings.dat") }
      let(:output_path) { Pathname(output_file.path) }

      before do
        input_file.write(toml_string)
        input_file.rewind
      end

      after do
        input_file.close
        input_file.unlink
        output_file.close
        output_file.unlink
      end

      it "raises error for invalid format" do
        expect {
          command.call(input: input_file.path, format: "xml", settings_file: output_path.to_s)
        }.to raise_error(ArgumentError, /Unknown format: xml/)
      end
    end
  end
end
