# frozen_string_literal: true

require "fileutils"
require "tempfile"

RSpec.describe Factorix::Runtime do
  describe ".runtime" do
    subject(:runtime) { Factorix::Runtime.runtime }

    context "on MacOS" do
      before do
        stub_const("RUBY_PLATFORM", "arm64-darwin24")
      end

      it "returns MacOS runtime" do
        expect(runtime).to be_a(Factorix::Runtime::MacOS)
      end
    end

    context "on Windows" do
      before do
        stub_const("RUBY_PLATFORM", "x86_64-mingw32")
      end

      it "returns Windows runtime" do
        expect(runtime).to be_a(Factorix::Runtime::Windows)
      end
    end

    context "on WSL" do
      before do
        stub_const("RUBY_PLATFORM", "x86_64-linux")
        allow(File).to receive(:read).with("/proc/version").and_return(
          "Linux version 4.4.0-18362-Microsoft (user@buildmachine) " \
          "(gcc version 8.3.0 (GCC)) #1 SMP Tue Nov 10 12:53:03 PST 2020"
        )
      end

      it "returns WSL runtime" do
        expect(runtime).to be_a(Factorix::Runtime::WSL)
      end
    end

    context "on non-WSL Linux" do
      before do
        stub_const("RUBY_PLATFORM", "x86_64-linux")
        allow(File).to receive(:read).with("/proc/version").and_return(
          "Linux version 5.4.0-80-generic (buildd@lcy01-amd64-023) " \
          "(gcc version 9.3.0 (Ubuntu 9.3.0-17ubuntu1~20.04)) #90-Ubuntu SMP Thu Jul 22 10:11:06 UTC 2021"
        )
      end

      it "returns Linux runtime" do
        expect(runtime).to be_a(Factorix::Runtime::Linux)
      end
    end

    context "on unsupported platform" do
      before do
        stub_const("RUBY_PLATFORM", "x86_64-freebsd")
      end

      it "raises UnsupportedPlatform" do
        expect { runtime }.to raise_error(Factorix::UnsupportedPlatformError)
      end
    end
  end

  describe "#mods_dir" do
    subject(:mods_dir) { runtime.mods_dir }

    let(:runtime) { Factorix::Runtime.new }

    before do
      allow(runtime).to receive(:user_dir).and_return(Pathname.new("/user_dir"))
    end

    it "returns the MODs directory of Factorio" do
      expect(mods_dir).to eq(Pathname.new("/user_dir/mods"))
    end
  end

  describe "#script_output_dir" do
    subject(:script_output_dir) { runtime.script_output_dir }

    let(:runtime) { Factorix::Runtime.new }

    before do
      allow(runtime).to receive(:user_dir).and_return(Pathname.new("/user_dir"))
    end

    it "returns the script-output directory of Factorio" do
      expect(script_output_dir).to eq(Pathname.new("/user_dir/script-output"))
    end
  end

  describe "#mod_list_path" do
    subject(:mod_list_path) { runtime.mod_list_path }

    let(:runtime) { Factorix::Runtime.new }

    before do
      allow(runtime).to receive(:user_dir).and_return(Pathname.new("/user_dir"))
    end

    it "returns the path of the mod-list.json file" do
      expect(mod_list_path).to eq(Pathname.new("/user_dir/mods/mod-list.json"))
    end
  end

  describe "#mod_settings_path" do
    subject(:mod_settings_path) { runtime.mod_settings_path }

    let(:runtime) { Factorix::Runtime.new }

    before do
      allow(runtime).to receive(:mods_dir).and_return(Pathname.new("/user_dir/mods"))
    end

    it "returns the path of the mod-settings.dat file" do
      expect(mod_settings_path).to eq(Pathname.new("/user_dir/mods/mod-settings.dat"))
    end
  end

  describe "#player_data_path" do
    subject(:player_data_path) { runtime.player_data_path }

    let(:runtime) { Factorix::Runtime.new }

    before do
      allow(runtime).to receive(:user_dir).and_return(Pathname.new("/user_dir"))
    end

    it "returns the path of the player-data.json file" do
      expect(player_data_path).to eq(Pathname.new("/user_dir/player-data.json"))
    end
  end

  describe "#running?" do
    subject(:running?) { runtime.running? }

    let(:runtime) { Factorix::Runtime.new }
    let(:lock_path) { instance_double(Pathname) }

    before do
      allow(runtime).to receive(:lock_path).and_return(lock_path)
    end

    context "when the lock file exists" do
      before do
        allow(lock_path).to receive(:exist?).and_return(true)
      end

      it "returns true" do
        expect(running?).to be true
      end
    end

    context "when the lock file does not exist" do
      before do
        allow(lock_path).to receive(:exist?).and_return(false)
      end

      it "returns false" do
        expect(running?).to be false
      end
    end
  end

  describe "#launch" do
    let(:runtime) { Factorix::Runtime.new }

    describe "when the game is not running, async: true, without arguments" do
      subject(:launch) { runtime.launch(async: true) }

      before do
        allow(runtime).to receive_messages(
          running?: false,
          executable: Pathname.new("/path/to/factorio")
        )
        allow(runtime).to receive(:spawn)
        allow(runtime).to receive(:system)
      end

      it "launches the game asynchronously" do
        launch
        expect(runtime).to have_received(:spawn).with(["/path/to/factorio", "factorio"], out: IO::NULL)
      end

      it "does not use system for asynchronous launch" do
        launch
        expect(runtime).not_to have_received(:system)
      end
    end

    describe "when the game is not running, async: true, with arguments" do
      subject(:launch) { runtime.launch("--start-server", "save.zip", async: true) }

      before do
        allow(runtime).to receive_messages(
          running?: false,
          executable: Pathname.new("/path/to/factorio")
        )
        allow(runtime).to receive(:spawn)
        allow(runtime).to receive(:system)
      end

      it "launches the game asynchronously with arguments" do
        launch
        expect(runtime).to have_received(:spawn).with(["/path/to/factorio", "factorio"], "--start-server", "save.zip", out: IO::NULL)
      end

      it "does not use system for asynchronous launch with arguments" do
        launch
        expect(runtime).not_to have_received(:system)
      end
    end

    describe "when the game is not running, async: false, without arguments" do
      subject(:launch) { runtime.launch(async: false) }

      before do
        allow(runtime).to receive_messages(
          running?: false,
          executable: Pathname.new("/path/to/factorio")
        )
        allow(runtime).to receive(:spawn)
        allow(runtime).to receive(:system)
      end

      it "launches the game synchronously" do
        launch
        expect(runtime).to have_received(:system).with(["/path/to/factorio", "factorio"], out: IO::NULL)
      end

      it "does not use spawn for synchronous launch" do
        launch
        expect(runtime).not_to have_received(:spawn)
      end
    end

    describe "when the game is not running, async: false, with arguments" do
      subject(:launch) { runtime.launch("--start-server", "save.zip", async: false) }

      before do
        allow(runtime).to receive_messages(
          running?: false,
          executable: Pathname.new("/path/to/factorio")
        )
        allow(runtime).to receive(:spawn)
        allow(runtime).to receive(:system)
      end

      it "launches the game synchronously with arguments" do
        launch
        expect(runtime).to have_received(:system).with(["/path/to/factorio", "factorio"], "--start-server", "save.zip", out: IO::NULL)
      end

      it "does not use spawn for synchronous launch with arguments" do
        launch
        expect(runtime).not_to have_received(:spawn)
      end
    end

    describe "when the game is already running" do
      before do
        allow(runtime).to receive(:running?).and_return(true)
      end

      it "raises AlreadyRunning" do
        expect { runtime.launch(async: true) }.to raise_error(Factorix::AlreadyRunningError)
      end
    end
  end

  describe "#with_only_mod_enabled" do
    let(:runtime) { Factorix::Runtime.new }
    let(:mod_list) { instance_double(Factorix::ModList) }
    let(:mod_context) { instance_double(Factorix::ModContext) }

    before do
      allow(Factorix::ModList).to receive(:load).and_return(mod_list)
      allow(Factorix::ModContext).to receive(:new).with(mod_list).and_return(mod_context)
      allow(mod_context).to receive(:with_only_enabled)
    end

    context "when calling the method" do
      before do
        runtime.with_only_mod_enabled("mod1", "mod2") { "test block" }
      end

      it "loads the MOD list" do
        expect(Factorix::ModList).to have_received(:load)
      end

      it "creates a ModContext with the loaded MOD list" do
        expect(Factorix::ModContext).to have_received(:new).with(mod_list)
      end

      it "calls with_only_enabled on the context with the specified MOD names" do
        expect(mod_context).to have_received(:with_only_enabled).with("mod1", "mod2")
      end
    end

    it "passes the block to with_only_enabled" do
      block_called = false

      # Setup mod_context to yield to the block
      allow(mod_context).to receive(:with_only_enabled) do |*, &block|
        block&.call
      end

      runtime.with_only_mod_enabled("mod1", "mod2") { block_called = true }

      expect(block_called).to be true
    end
  end

  describe "#with_only_mod_enabled integration", :integration do
    let(:runtime) { Factorix::Runtime.new }
    let(:mod_list_path) { Pathname("spec/fixtures/mod-list/list.json") }
    let(:base_mod) { Factorix::Mod[name: "base"] }
    let(:enabled_mod) { Factorix::Mod[name: "enabled-mod"] }
    let(:disabled_mod) { Factorix::Mod[name: "disabled-mod"] }
    let(:mod_context) { instance_double(Factorix::ModContext) }
    let(:mod_list) { instance_double(Factorix::ModList) }
    let(:enabled_states) { {} }

    before do
      # Mock the ModList.load to return our mock mod_list
      allow(Factorix::ModList).to receive(:load).and_return(mod_list)

      # Mock the ModContext.new to return our mock mod_context
      allow(Factorix::ModContext).to receive(:new).with(mod_list).and_return(mod_context)

      # Setup the mod_context to track enabled states during block execution
      allow(mod_context).to receive(:with_only_enabled) do |*mod_names, &block|
        # Record which MODs would be enabled during the block
        enabled_states["base"] = true # base is always enabled
        mod_names.each do |name|
          enabled_states[name] = true
        end
        # Any MOD not in mod_names and not base would be disabled
        %w[enabled-mod disabled-mod].each do |name|
          enabled_states[name] = false unless name == "base" || mod_names.include?(name)
        end

        # Call the block if given
        block&.call
      end
    end

    context "when enabling a specific MOD" do
      before do
        runtime.with_only_mod_enabled("disabled-mod") { "test block" }
      end

      it "enables the base MOD" do
        expect(enabled_states["base"]).to be true
      end

      it "enables the specified MOD" do
        expect(enabled_states["disabled-mod"]).to be true
      end

      it "disables other MODs" do
        expect(enabled_states["enabled-mod"]).to be false
      end
    end

    it "passes the block to the context's with_only_enabled method" do
      block_called = false

      # Run with_only_mod_enabled with a block that sets block_called to true
      runtime.with_only_mod_enabled("disabled-mod") { block_called = true }

      # Verify that the block was called
      expect(block_called).to be true
    end
  end
end
