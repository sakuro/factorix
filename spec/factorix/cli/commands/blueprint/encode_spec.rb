# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::CLI::Commands::Blueprint::Encode do
  let(:command) { Factorix::CLI::Commands::Blueprint::Encode.new }
  let(:data) { {"blueprint" => {"item" => "blueprint", "version" => 1}} }
  let(:json_string) { JSON.pretty_generate(data) }

  describe "#call" do
    context "when reading from stdin" do
      it "encodes the JSON to a blueprint string" do
        allow($stdin).to receive(:read).and_return(json_string)
        result = run_command(command)
        expect(result.stdout).to start_with("0")
      end
    end

    context "when reading from a file" do
      let(:input_file) { Tempfile.new(["decoded", ".json"]) }

      before do
        input_file.write(json_string)
        input_file.flush
      end

      after { input_file.close && input_file.unlink }

      it "encodes the JSON from the file to a blueprint string" do
        result = run_command(command, [input_file.path])
        expect(result.stdout).to start_with("0")
      end
    end

    context "when writing to an output file" do
      let(:input_file) { Tempfile.new(["decoded", ".json"]) }
      let(:output_file) { Tempfile.new(["blueprint", ".txt"]) }

      before do
        input_file.write(json_string)
        input_file.flush
      end

      after do
        input_file.close && input_file.unlink
        output_file.close && output_file.unlink
      end

      it "writes the blueprint string to the output file" do
        run_command(command, [input_file.path, "--output=#{output_file.path}"])
        expect(output_file.read).to start_with("0")
      end

      it "does not write to stdout" do
        result = run_command(command, [input_file.path, "--output=#{output_file.path}"])
        expect(result.stdout).to be_empty
      end
    end

    context "when decoding the result" do
      let(:input_file) { Tempfile.new(["decoded", ".json"]) }

      before do
        input_file.write(json_string)
        input_file.flush
      end

      after { input_file.close && input_file.unlink }

      it "produces a blueprint string that decodes back to the original data" do
        result = run_command(command, [input_file.path])
        blueprint = Factorix::Blueprint.decode(result.stdout)
        expect(blueprint.data).to eq(data)
      end
    end
  end
end
