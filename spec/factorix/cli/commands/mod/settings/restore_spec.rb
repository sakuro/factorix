# frozen_string_literal: true

require "fileutils"
require "tempfile"

RSpec.describe Factorix::CLI::Commands::MOD::Settings::Restore do
  let(:command) { Factorix::CLI::Commands::MOD::Settings::Restore.new(runtime:) }

  let(:runtime) do
    instance_double(
      Factorix::Runtime::Base,
      factorix_config_path: Pathname("/tmp/factorix/config.rb"),
      running?: false
    )
  end

  let(:game_version) { Factorix::GameVersion.from_string("1.1.0-42") }
  let(:startup_section) do
    section = Factorix::MODSettings::Section.new("startup")
    section["string-value"] = "test"
    section["bool-value"] = true
    section["float-value"] = 1.5
    section["int-value"] = Factorix::SerDes::SignedInteger.new(42)
    section
  end
  let(:sections) { {"startup" => startup_section} }
  let(:settings) { Factorix::MODSettings.new(game_version, sections) }
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
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:runtime).and_return(runtime)
    allow(settings).to receive(:save)
    allow(runtime).to receive(:mod_settings_path).and_return(Pathname("/default/mod-settings.dat"))
    allow(Factorix::MODSettings).to receive(:new).and_return(settings)
  end

  describe "#call" do
    context "with JSON input file" do
      let(:input_file) { Tempfile.new(["input", ".json"]) }
      let(:output_file) { Tempfile.new("mod-settings.dat") }
      let(:output_path) { Pathname(output_file.path) }

      before do
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

        expect(settings).to have_received(:save).with(output_path)
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
        allow($stdin).to receive(:read).and_return(json_string)
      end

      it "reads from stdin when no input file specified" do
        command.call(settings_file: output_path.to_s)

        expect($stdin).to have_received(:read)
        expect(settings).to have_received(:save).with(output_path)
      end
    end

    context "with custom output file" do
      let(:input_file) { Tempfile.new(["input", ".json"]) }
      let(:custom_output_file) { Tempfile.new("mod-settings.dat") }

      before do
        input_file.write(json_string)
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

        expect(settings).to have_received(:save).with(Pathname(custom_output_file.path))
      end
    end

    context "with default output file" do
      let(:input_file) { Tempfile.new(["input", ".json"]) }
      let(:default_path) { instance_double(Pathname, exist?: false) }

      before do
        allow(runtime).to receive(:mod_settings_path).and_return(default_path)
        input_file.write(json_string)
        input_file.rewind
      end

      after do
        input_file.close
        input_file.unlink
      end

      it "saves to default path when settings_file not specified" do
        command.call(input: input_file.path)

        expect(settings).to have_received(:save).with(default_path)
      end
    end

    context "with backup" do
      let(:input_file) { Tempfile.new(["input", ".json"]) }
      let(:output_file) { Tempfile.new("mod-settings.dat") }
      let(:output_path) { Pathname(output_file.path) }

      before do
        input_file.write(json_string)
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
  end
end
