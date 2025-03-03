# frozen_string_literal: true

require "tempfile"
require_relative "../../../../../lib/factorix/cli/commands/mod/disable"

RSpec.describe Factorix::CLI::Commands::Mod::Disable do
  let(:command) { Factorix::CLI::Commands::Mod::Disable.new }
  let(:mod_name) { "test-mod" }

  describe "#call with mocked ModList" do
    let(:mod_list) { instance_double(Factorix::ModList) }

    before do
      allow(Factorix::ModList).to receive(:load).and_return(mod_list)
      allow(mod_list).to receive(:disable)
      allow(mod_list).to receive(:save)
    end

    context "with verbose option" do
      let(:options) { {verbose: true} }

      it "outputs disabling message" do
        expect { command.call(mod: mod_name, **options) }.to output(/Disabling MOD: #{mod_name}/).to_stdout
      end

      it "disables the mod in the mod list" do
        command.call(mod: mod_name, **options)
        expect(mod_list).to have_received(:disable).with(Factorix::Mod[name: mod_name])
      end

      it "saves the mod list" do
        command.call(mod: mod_name, **options)
        expect(mod_list).to have_received(:save)
      end
    end

    context "without verbose option" do
      let(:options) { {verbose: false} }

      it "does not output disabling message" do
        expect { command.call(mod: mod_name, **options) }.not_to output.to_stdout
      end

      it "disables the mod in the mod list" do
        command.call(mod: mod_name, **options)
        expect(mod_list).to have_received(:disable).with(Factorix::Mod[name: mod_name])
      end

      it "saves the mod list" do
        command.call(mod: mod_name, **options)
        expect(mod_list).to have_received(:save)
      end
    end
  end

  describe "#call with actual file operations" do
    let(:options) { {verbose: false} }
    let(:mod_list_content) do
      {
        mods: [
          {name: "base", enabled: true},
          {name: mod_name, enabled: true}
        ]
      }
    end
    let(:temp_file) { Tempfile.new(["mod-list-", ".json"]) }
    let(:mod_list_path) { Pathname(temp_file.path) }
    let(:runtime) { instance_double(Factorix::Runtime) }

    before do
      temp_file.write(JSON.pretty_generate(mod_list_content))
      temp_file.flush

      allow(Factorix::Runtime).to receive(:runtime).and_return(runtime)
      allow(runtime).to receive(:mod_list_path).and_return(mod_list_path)
    end

    after do
      temp_file.close
      temp_file.unlink
    end

    it "updates the mod-list.json file" do
      command.call(mod: mod_name, **options)

      # Verify the file was updated
      updated_content = JSON.parse(File.read(temp_file.path))
      expect(updated_content["mods"].find {|m| m["name"] == mod_name }["enabled"]).to be false
    end
  end
end
