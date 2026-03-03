# frozen_string_literal: true

require "base64"
require "tempfile"
require "zlib"

RSpec.describe Factorix::CLI::Commands::Blueprint::Decode do
  let(:command) { Factorix::CLI::Commands::Blueprint::Decode.new }
  let(:data) { {"blueprint" => {"item" => "blueprint", "version" => 1}} }
  let(:blueprint_string) do
    compressed = Zlib::Deflate.deflate(JSON.generate(data))
    "0#{Base64.strict_encode64(compressed)}"
  end

  describe "#call" do
    context "when reading from stdin" do
      it "decodes the blueprint string to JSON" do
        allow($stdin).to receive(:read).and_return(blueprint_string)
        result = run_command(command)
        expect(result.stdout).to include('"blueprint"')
        expect(result.stdout).to include('"item"')
      end
    end

    context "when reading from a file" do
      let(:input_file) { Tempfile.new(["blueprint", ".txt"]) }

      before do
        input_file.write(blueprint_string)
        input_file.flush
      end

      after { input_file.close && input_file.unlink }

      it "decodes the blueprint string from the file" do
        result = run_command(command, [input_file.path])
        expect(result.stdout).to include('"blueprint"')
      end
    end

    context "when writing to an output file" do
      let(:input_file) { Tempfile.new(["blueprint", ".txt"]) }
      let(:output_file) { Tempfile.new(["decoded", ".json"]) }

      before do
        input_file.write(blueprint_string)
        input_file.flush
      end

      after do
        input_file.close && input_file.unlink
        output_file.close && output_file.unlink
      end

      it "writes JSON to the output file" do
        run_command(command, [input_file.path, "--output=#{output_file.path}"])
        expect(output_file.read).to include('"blueprint"')
      end

      it "does not write to stdout" do
        result = run_command(command, [input_file.path, "--output=#{output_file.path}"])
        expect(result.stdout).to be_empty
      end
    end
  end
end
