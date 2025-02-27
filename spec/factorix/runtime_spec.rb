# frozen_string_literal: true

require "factorix/runtime"

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
        expect { runtime }.to raise_error(Factorix::Runtime::UnsupportedPlatform)
      end
    end
  end

  describe "#mods_dir" do
    subject(:mods_dir) { runtime.mods_dir }

    let(:runtime) { Factorix::Runtime.runtime }

    before do
      allow(runtime).to receive(:user_dir).and_return(Pathname.new("/user_dir"))
    end

    it "returns the mods directory of Factorio" do
      expect(mods_dir).to eq(Pathname.new("/user_dir/mods"))
    end
  end

  describe "#script_output_dir" do
    subject(:script_output_dir) { runtime.script_output_dir }

    let(:runtime) { Factorix::Runtime.runtime }

    before do
      allow(runtime).to receive(:user_dir).and_return(Pathname.new("/user_dir"))
    end

    it "returns the script-output directory of Factorio" do
      expect(script_output_dir).to eq(Pathname.new("/user_dir/script-output"))
    end
  end

  describe "#mod_list_path" do
    subject(:mod_list_path) { runtime.mod_list_path }

    let(:runtime) { Factorix::Runtime.runtime }

    before do
      allow(runtime).to receive(:user_dir).and_return(Pathname.new("/user_dir"))
    end

    it "returns the path of the mod-list.json file" do
      expect(mod_list_path).to eq(Pathname.new("/user_dir/mods/mod-list.json"))
    end
  end

  describe "#launch" do
    let(:runtime) { Factorix::Runtime.runtime }

    context "when the game is not running" do
      before do
        allow(runtime).to receive_messages(
          running?: false,
          executable: Pathname.new("/path/to/factorio")
        )
        allow(runtime).to receive(:spawn)
        allow(runtime).to receive(:system)
      end

      context "with async: true" do
        context "without arguments" do
          subject(:launch) { runtime.launch(async: true) }

          it "launches the game asynchronously" do
            launch
            expect(runtime).to have_received(:spawn).with(["/path/to/factorio", "factorio"], out: IO::NULL)
          end

          it "does not use system for asynchronous launch" do
            launch
            expect(runtime).not_to have_received(:system)
          end
        end

        context "with arguments" do
          subject(:launch) { runtime.launch("--start-server", "save.zip", async: true) }

          it "launches the game asynchronously with arguments" do
            launch
            expect(runtime).to have_received(:spawn).with(["/path/to/factorio", "factorio"], "--start-server", "save.zip", out: IO::NULL)
          end

          it "does not use system for asynchronous launch with arguments" do
            launch
            expect(runtime).not_to have_received(:system)
          end
        end
      end

      context "with async: false" do
        context "without arguments" do
          subject(:launch) { runtime.launch(async: false) }

          it "launches the game synchronously" do
            launch
            expect(runtime).to have_received(:system).with(["/path/to/factorio", "factorio"], out: IO::NULL)
          end

          it "does not use spawn for synchronous launch" do
            launch
            expect(runtime).not_to have_received(:spawn)
          end
        end

        context "with arguments" do
          subject(:launch) { runtime.launch("--start-server", "save.zip", async: false) }

          it "launches the game synchronously with arguments" do
            launch
            expect(runtime).to have_received(:system).with(["/path/to/factorio", "factorio"], "--start-server", "save.zip", out: IO::NULL)
          end

          it "does not use spawn for synchronous launch with arguments" do
            launch
            expect(runtime).not_to have_received(:spawn)
          end
        end
      end
    end

    context "when the game is already running" do
      before do
        allow(runtime).to receive(:running?).and_return(true)
      end

      it "raises AlreadyRunning" do
        expect { runtime.launch(async: true) }.to raise_error(Factorix::Runtime::AlreadyRunning)
      end
    end
  end
end
