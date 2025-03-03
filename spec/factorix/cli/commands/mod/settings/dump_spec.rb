# frozen_string_literal: true

require "tempfile"
require_relative "../../../../../../lib/factorix/cli/commands/mod/settings/dump"

RSpec.describe Factorix::CLI::Commands::Mod::Settings::Dump do
  let(:command) { Factorix::CLI::Commands::Mod::Settings::Dump.new }
  let(:runtime) { instance_double(Factorix::Runtime) }
  let(:settings_path) { Pathname.new("/path/to/mod-settings.dat") }
  let(:mod_settings) { instance_double(Factorix::ModSettings) }
  let(:startup_section) { instance_double(Factorix::ModSettings::Section, name: "startup", empty?: false) }
  let(:runtime_global_section) {
    instance_double(Factorix::ModSettings::Section, name: "runtime-global", empty?: false)
  }
  let(:runtime_per_user_section) {
    instance_double(Factorix::ModSettings::Section, name: "runtime-per-user", empty?: false)
  }
  let(:expected_settings_hash) do
    {
      "startup" => {
        "setting-1" => true,
        "setting-2" => 42
      },
      "runtime-global" => {
        "global-setting" => "value",
        "color-setting" => {"r" => 0.5, "g" => 0.7, "b" => 0.3, "a" => 1.0}
      },
      "runtime-per-user" => {
        "user-setting" => [1, 2, 3]
      }
    }
  end

  before do
    allow(Factorix::Runtime).to receive(:runtime).and_return(runtime)
    allow(runtime).to receive(:mod_settings_path).and_return(settings_path)
    allow(settings_path).to receive(:exist?).and_return(true)
    allow(Factorix::ModSettings).to receive(:new).with(settings_path).and_return(mod_settings)

    # Setup sections
    allow(mod_settings).to receive(:each_section)
      .and_yield(startup_section)
      .and_yield(runtime_global_section)
      .and_yield(runtime_per_user_section)

    # Setup startup section
    allow(startup_section).to receive(:each).and_yield("setting-1", true).and_yield("setting-2", 42)

    # Setup runtime-global section
    allow(runtime_global_section).to receive(:each).and_yield("global-setting", "value").and_yield(
      "color-setting",
      {"r" => 0.5, "g" => 0.7, "b" => 0.3, "a" => 1.0}
    )

    # Setup runtime-per-user section
    allow(runtime_per_user_section).to receive(:each).and_yield("user-setting", [1, 2, 3])

    # Setup build_settings_hash to return the expected hash
    allow(command).to receive(:build_settings_hash).with(mod_settings).and_return(expected_settings_hash)

    # Setup PerfectTOML.generate
    allow(PerfectTOML).to receive(:generate).with(expected_settings_hash).and_return(
      <<~TOML
        [startup]
        setting-1 = true
        setting-2 = 42

        [runtime-global]
        global-setting = "value"
        color-setting = { r = 0.5, g = 0.7, b = 0.3, a = 1.0 }

        [runtime-per-user]
        user-setting = [1, 2, 3]
      TOML
    )
  end

  describe "#call" do
    let(:options) { {} }

    it "outputs settings in TOML format" do
      expected_output = <<~OUTPUT
        [startup]
        setting-1 = true
        setting-2 = 42

        [runtime-global]
        global-setting = "value"
        color-setting = { r = 0.5, g = 0.7, b = 0.3, a = 1.0 }

        [runtime-per-user]
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
