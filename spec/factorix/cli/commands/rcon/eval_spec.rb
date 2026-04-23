# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::RCon::Eval do
  let(:rcon_client) { instance_double(RCon::Client) }

  before do
    allow(RCon::Client).to receive(:open).and_yield(rcon_client)
    allow(rcon_client).to receive(:execute).and_return("")
  end

  describe "#call" do
    context "when a script is given as an argument" do
      it "executes the script wrapped in /c" do
        run_command(Factorix::CLI::Commands::RCon::Eval, %w[rcon.print(game.tick)])

        expect(rcon_client).to have_received(:execute).with("/c rcon.print(game.tick)")
      end
    end

    context "when no script is given" do
      it "reads the script from stdin" do
        allow($stdin).to receive(:read).and_return("rcon.print(game.tick)")

        run_command(Factorix::CLI::Commands::RCon::Eval)

        expect(rcon_client).to have_received(:execute).with("/c rcon.print(game.tick)")
      end
    end

    it "connects with config defaults" do
      run_command(Factorix::CLI::Commands::RCon::Eval, %w[rcon.print(game.tick)])

      expect(RCon::Client).to have_received(:open).with("localhost", 27015, password: nil, sentinel_command: "/c")
    end

    it "uses CLI options to override connection settings" do
      run_command(Factorix::CLI::Commands::RCon::Eval, %w[--host rconserver --port 25575 --password secret rcon.print(game.tick)])

      expect(RCon::Client).to have_received(:open).with("rconserver", 25575, password: "secret", sentinel_command: "/c")
    end

    context "when the server returns output" do
      before { allow(rcon_client).to receive(:execute).and_return("3600") }

      it "prints the output" do
        result = run_command(Factorix::CLI::Commands::RCon::Eval, %w[rcon.print(game.tick)])

        expect(result.stdout).to include("3600")
      end
    end

    context "when the server returns no output" do
      it "prints nothing" do
        result = run_command(Factorix::CLI::Commands::RCon::Eval, %w[rcon.print(game.tick)])

        expect(result.stdout).to eq("")
      end
    end

    context "when the connection fails" do
      before { allow(RCon::Client).to receive(:open).and_raise(RCon::Client::ConnectionError, "connection refused") }

      it "raises RConConnectionError" do
        expect {
          run_command(Factorix::CLI::Commands::RCon::Eval, %w[rcon.print(game.tick)])
        }.to raise_error(Factorix::RConConnectionError, "connection refused")
      end
    end

    context "when authentication fails" do
      before { allow(RCon::Client).to receive(:open).and_raise(RCon::Client::AuthenticationError, "bad password") }

      it "raises RConAuthenticationError" do
        expect {
          run_command(Factorix::CLI::Commands::RCon::Eval, %w[rcon.print(game.tick)])
        }.to raise_error(Factorix::RConAuthenticationError, "bad password")
      end
    end
  end
end
