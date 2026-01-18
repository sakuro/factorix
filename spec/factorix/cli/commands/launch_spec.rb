# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Launch do
  let(:runtime) { instance_double(Factorix::Runtime::Base) }
  let(:logger) { instance_double(Dry::Logger::Dispatcher, info: nil, debug: nil, error: nil) }
  let(:command) { Factorix::CLI::Commands::Launch.new(runtime:, logger:) }

  before do
    allow(runtime).to receive(:executable_path).and_return(Pathname("/path/to/factorio"))
    allow(runtime).to receive(:launch)
    allow(command).to receive(:wait_while)
  end

  describe "#call" do
    context "when the game is already running" do
      before do
        allow(runtime).to receive(:running?).and_return(true)
      end

      it "raises GameRunningError" do
        expect { run_command(command) }.to raise_error(Factorix::GameRunningError)
      end
    end

    context "when the game is not running with no special args" do
      before do
        allow(runtime).to receive(:running?).and_return(false, true, false)
      end

      it "launches the game asynchronously" do
        run_command(command)

        expect(runtime).to have_received(:launch).with(async: true)
      end
    end

    context "when the game is not running with no special args and wait option" do
      before do
        allow(runtime).to receive(:running?).and_return(false, true, false)
      end

      it "waits for the game to start and finish" do
        run_command(command, %w[--wait])

        expect(command).to have_received(:wait_while).twice
      end
    end

    context "when the game is not running without wait option" do
      before do
        allow(runtime).to receive(:running?).and_return(false)
      end

      it "does not wait for the game" do
        run_command(command)

        expect(command).not_to have_received(:wait_while)
      end
    end

    context "when the game is not running with synchronous args" do
      before do
        allow(runtime).to receive(:running?).and_return(false)
      end

      it "launches the game synchronously" do
        run_command(command, %w[-- --dump-data])

        expect(runtime).to have_received(:launch).with("--dump-data", async: false)
      end
    end

    context "when the game is not running with synchronous args and wait option" do
      before do
        allow(runtime).to receive(:running?).and_return(false)
      end

      it "does not wait for the game" do
        run_command(command, %w[--wait -- --dump-data])

        expect(command).not_to have_received(:wait_while)
      end
    end

    context "when the game is not running with --help option" do
      before do
        allow(runtime).to receive(:running?).and_return(false)
      end

      it "launches the game synchronously" do
        run_command(command, %w[-- --help])

        expect(runtime).to have_received(:launch).with("--help", async: false)
      end
    end

    context "when the game is not running with --version option" do
      before do
        allow(runtime).to receive(:running?).and_return(false)
      end

      it "launches the game synchronously" do
        run_command(command, %w[-- --version])

        expect(runtime).to have_received(:launch).with("--version", async: false)
      end
    end

    context "when the game is not running with other args" do
      before do
        allow(runtime).to receive(:running?).and_return(false)
      end

      it "passes the args to the runtime with async: true" do
        run_command(command, %w[-- --start-server save.zip])

        expect(runtime).to have_received(:launch).with("--start-server", "save.zip", async: true)
      end
    end
  end

  describe "#wait_while" do
    before do
      allow(command).to receive(:wait_while).and_call_original
      allow(command).to receive(:sleep)
    end

    it "loops until the condition is false" do
      counter = 0
      condition = -> { (counter += 1) < 3 }

      command.__send__(:wait_while, &condition)

      expect(counter).to eq(3)
    end
  end
end
