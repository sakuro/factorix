# frozen_string_literal: true

require "factorix/cli/commands/mod/settings/dump"
require "tempfile"

RSpec.describe Factorix::CLI::Commands::Mod::Settings::Dump do
  let(:command) { Factorix::CLI::Commands::Mod::Settings::Dump.new }
  let(:runtime) { instance_double(Factorix::Runtime) }
  let(:settings_path) { Pathname.new("/path/to/mod-settings.dat") }
  let(:dummy_settings) do
    {
      "startup" => {
        "example-mod" => {
          "setting-1" => true,
          "setting-2" => 42
        }
      },
      "runtime-global" => {
        "example-mod" => {
          "global-setting" => "value"
        },
        "another-mod" => {
          "color-setting" => {"r" => 0.5, "g" => 0.7, "b" => 0.3, "a" => 1.0}
        }
      },
      "runtime-per-user" => {
        "example-mod" => {
          "user-setting" => [1, 2, 3]
        }
      }
    }
  end

  before do
    allow(Factorix::Runtime).to receive(:runtime).and_return(runtime)
    allow(runtime).to receive(:mod_settings_path).and_return(settings_path)
    allow(settings_path).to receive(:exist?).and_return(true)
    allow(command).to receive(:parse_settings_file).with(settings_path).and_return(dummy_settings)
    allow(PerfectTOML).to receive(:generate).with(dummy_settings).and_return(
      <<~TOML
        [startup.example-mod]
        setting-1 = true
        setting-2 = 42

        [runtime-global.example-mod]
        global-setting = "value"

        [runtime-global.another-mod]
        color-setting = { r = 0.5, g = 0.7, b = 0.3, a = 1.0 }

        [runtime-per-user.example-mod]
        user-setting = [1, 2, 3]
      TOML
    )
  end

  describe "#call" do
    let(:options) { {} }

    it "outputs settings in TOML format" do
      expected_output = <<~OUTPUT
        [startup.example-mod]
        setting-1 = true
        setting-2 = 42

        [runtime-global.example-mod]
        global-setting = "value"

        [runtime-global.another-mod]
        color-setting = { r = 0.5, g = 0.7, b = 0.3, a = 1.0 }

        [runtime-per-user.example-mod]
        user-setting = [1, 2, 3]
      OUTPUT
      expect { command.call(**options) }.to output(expected_output).to_stdout
    end

    context "when settings file does not exist" do
      before do
        allow(settings_path).to receive(:exist?).and_return(false)
      end

      it "outputs an error message" do
        expected_output = "Settings file not found: #{settings_path}\n"
        expect { command.call(**options) }.to output(expected_output).to_stdout
      end
    end
  end
end
