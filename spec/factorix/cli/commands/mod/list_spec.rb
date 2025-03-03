# frozen_string_literal: true

require "tempfile"
require_relative "../../../../../lib/factorix/cli/commands/mod/list"

RSpec.describe Factorix::CLI::Commands::Mod::List do
  let(:command) { Factorix::CLI::Commands::Mod::List.new }
  let(:mod_list) { instance_double(Factorix::ModList) }
  let(:base_mod) { Factorix::Mod[name: "base"] }
  let(:enabled_mod) { Factorix::Mod[name: "enabled-mod"] }
  let(:disabled_mod) { Factorix::Mod[name: "disabled-mod"] }
  let(:base_state) { Factorix::ModState[enabled: true, version: nil] }
  let(:enabled_state) { Factorix::ModState[enabled: true, version: "1.0.0"] }
  let(:disabled_state) { Factorix::ModState[enabled: false, version: nil] }

  before do
    allow(Factorix::ModList).to receive(:load).and_return(mod_list)
    allow(mod_list).to receive(:each).and_yield(base_mod, base_state)
      .and_yield(enabled_mod, enabled_state)
      .and_yield(disabled_mod, disabled_state)
    allow(mod_list).to receive(:each_mod).and_yield(base_mod)
      .and_yield(enabled_mod)
      .and_yield(disabled_mod)
    allow(mod_list).to receive(:map).and_return([
                                                  [base_mod.name, base_state.enabled, base_state.version],
                                                  [enabled_mod.name, enabled_state.enabled, enabled_state.version],
                                                  [disabled_mod.name, disabled_state.enabled, disabled_state.version]
                                                ])
  end

  describe "#call with default format" do
    let(:options) { {} }

    it "outputs mod names only" do
      expected_output = <<~OUTPUT
        base
        enabled-mod
        disabled-mod
      OUTPUT
      expect { command.call(**options) }.to output(expected_output).to_stdout
    end
  end

  describe "#call with csv format" do
    let(:options) { {format: "csv"} }

    it "outputs CSV with headers and mod data" do
      expected_output = <<~OUTPUT
        Name,Enabled,Version
        base,true,
        enabled-mod,true,1.0.0
        disabled-mod,false,
      OUTPUT
      expect { command.call(**options) }.to output(expected_output).to_stdout
    end
  end

  describe "#call with markdown format" do
    let(:options) { {format: "markdown"} }

    it "outputs markdown table with headers and mod data" do
      # Use left alignment for all columns
      expected_output = <<~OUTPUT
        |Name|Enabled|Version|
        |:-|:-|:-|
        |base|true||
        |enabled-mod|true|1.0.0|
        |disabled-mod|false||
      OUTPUT
      expect { command.call(**options) }.to output(expected_output).to_stdout
    end
  end

  describe "#call with actual file operations" do
    let(:options) { {} }
    let(:mod_list_content) do
      {
        mods: [
          {name: "base", enabled: true},
          {name: "enabled-mod", enabled: true, version: "1.0.0"},
          {name: "disabled-mod", enabled: false}
        ]
      }
    end
    let(:temp_file) { Tempfile.new(["mod-list-", ".json"]) }
    let(:mod_list_path) { Pathname(temp_file.path) }
    let(:runtime) { instance_double(Factorix::Runtime) }

    before do
      temp_file.write(JSON.pretty_generate(mod_list_content))
      temp_file.flush

      # Allow the real ModList.load to be called
      allow(Factorix::ModList).to receive(:load).and_call_original

      allow(Factorix::Runtime).to receive(:runtime).and_return(runtime)
      allow(runtime).to receive(:mod_list_path).and_return(mod_list_path)
    end

    after do
      temp_file.close
      temp_file.unlink
    end

    it "reads from the mod-list.json file" do
      expected_output = <<~OUTPUT
        base
        enabled-mod
        disabled-mod
      OUTPUT
      expect { command.call(**options) }.to output(expected_output).to_stdout
    end

    context "with csv format" do
      let(:options) { {format: "csv"} }

      it "outputs CSV with headers and mod data" do
        expected_output = <<~OUTPUT
          Name,Enabled,Version
          base,true,
          enabled-mod,true,1.0.0
          disabled-mod,false,
        OUTPUT
        expect { command.call(**options) }.to output(expected_output).to_stdout
      end
    end

    context "with markdown format" do
      let(:options) { {format: "markdown"} }

      it "outputs markdown table with headers and mod data" do
        # Use left alignment for all columns
        expected_output = <<~OUTPUT
          |Name|Enabled|Version|
          |:-|:-|:-|
          |base|true||
          |enabled-mod|true|1.0.0|
          |disabled-mod|false||
        OUTPUT
        expect { command.call(**options) }.to output(expected_output).to_stdout
      end
    end
  end
end
