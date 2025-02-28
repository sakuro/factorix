# frozen_string_literal: true

require "factorix/cli/commands/mod/settings/dump"
require "tempfile"

RSpec.describe Factorix::CLI::Commands::Mod::Settings::Dump do
  let(:command) { Factorix::CLI::Commands::Mod::Settings::Dump.new }
  let(:runtime) { instance_double(Factorix::Runtime) }
  let(:settings_path) { Pathname.new("/path/to/mod-settings.dat") }
  let(:dummy_settings) do
    {
      "mod-setting" => {
        "startup" => {},
        "runtime-global" => {},
        "runtime-per-user" => {}
      }
    }
  end

  before do
    allow(Factorix::Runtime).to receive(:runtime).and_return(runtime)
    allow(runtime).to receive(:mod_settings_path).and_return(settings_path)
    allow(File).to receive(:exist?).with(settings_path).and_return(true)
    allow(PerfectTOML).to receive(:generate).with(dummy_settings).and_return(
      <<~TOML
        [mod-setting.startup]

        [mod-setting.runtime-global]

        [mod-setting.runtime-per-user]
      TOML
    )
  end

  describe "#call" do
    let(:options) { {} }

    it "outputs settings in TOML format" do
      expected_output = <<~OUTPUT
        [mod-setting.startup]

        [mod-setting.runtime-global]

        [mod-setting.runtime-per-user]
      OUTPUT
      expect { command.call(**options) }.to output(expected_output).to_stdout
    end

    context "when settings file does not exist" do
      before do
        allow(File).to receive(:exist?).with(settings_path).and_return(false)
      end

      it "outputs an error message" do
        expected_output = "Settings file not found: #{settings_path}\n"
        expect { command.call(**options) }.to output(expected_output).to_stdout
      end
    end
  end
end
