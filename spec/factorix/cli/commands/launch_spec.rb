# frozen_string_literal: true

require "factorix/cli/commands/launch"

RSpec.describe Factorix::CLI::Commands::Launch do
  let(:runtime) { Factorix::Runtime.new }
  let(:command) { Factorix::CLI::Commands::Launch.new }

  before do
    allow(Factorix::Runtime).to receive(:runtime).and_return(runtime)
    allow(runtime).to receive_messages(
      executable: Pathname("/path/to/factorio"),
      spawn: nil,
      system: nil
    )
  end

  describe "#call" do
    subject(:call) { command.call(args:, **options) }

    let(:args) { [] }
    let(:options) { {} }

    before do
      allow(runtime).to receive(:launch).and_call_original
      allow(command).to receive(:wait_while)
    end

    describe "when the game is already running" do
      before do
        allow(runtime).to receive(:running?).and_return(true)
      end

      it "raises AlreadyRunning" do
        expect { call }.to raise_error(Factorix::Runtime::AlreadyRunning)
      end
    end

    describe "when the game is not running with no special args" do
      before do
        allow(runtime).to receive(:running?).and_return(false, true, false)
      end

      it "launches the game asynchronously" do
        call
        expect(runtime).to have_received(:launch).with(async: true)
      end
    end

    describe "when the game is not running with no special args and wait option" do
      before do
        allow(runtime).to receive(:running?).and_return(false, true, false)
      end

      let(:options) { {wait: true} }

      it "waits for the game to start and finish" do
        call
        expect(command).to have_received(:wait_while).twice
      end
    end

    describe "when the game is not running with no special args and without wait option" do
      before do
        allow(runtime).to receive(:running?).and_return(false, true, false)
      end

      let(:options) { {wait: false} }

      it "does not wait for the game" do
        call
        expect(command).not_to have_received(:wait_while)
      end
    end

    describe "when the game is not running with synchronous args" do
      before do
        allow(runtime).to receive(:running?).and_return(false, true, false)
      end

      let(:args) { %w[--dump-data] }

      it "launches the game synchronously" do
        call
        expect(runtime).to have_received(:launch).with("--dump-data", async: false)
      end
    end

    describe "when the game is not running with synchronous args and wait option" do
      before do
        allow(runtime).to receive(:running?).and_return(false, true, false)
      end

      let(:args) { %w[--dump-data] }
      let(:options) { {wait: true} }

      it "does not wait for the game" do
        call
        expect(command).not_to have_received(:wait_while)
      end
    end

    describe "when the game is not running with other args" do
      before do
        allow(runtime).to receive(:running?).and_return(false, true, false)
      end

      let(:args) { %w[--start-server save.zip] }

      it "passes the args to the runtime with async: true" do
        call
        expect(runtime).to have_received(:launch).with("--start-server", "save.zip", async: true)
      end
    end
  end

  describe "#wait_while" do
    before do
      allow(command).to receive(:sleep)
    end

    it "loops until the condition is false" do
      counter = 0
      condition = -> { (counter += 1) < 3 }

      command.__send__(:wait_while) { condition.call }

      expect(counter).to eq(3)
    end
  end
end
