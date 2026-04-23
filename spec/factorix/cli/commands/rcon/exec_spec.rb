# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::RCon::Exec do
  let(:rcon_client) { instance_double(RCon::Client) }

  before do
    allow(RCon::Client).to receive(:open).and_yield(rcon_client)
    allow(rcon_client).to receive(:execute).and_return("")
  end

  describe "#call" do
    it "connects with config defaults and executes the command" do
      run_command(Factorix::CLI::Commands::RCon::Exec, %w[/server-save])

      expect(RCon::Client).to have_received(:open).with("localhost", 27015, password: nil, sentinel_command: "/c")
      expect(rcon_client).to have_received(:execute).with("/server-save")
    end

    it "uses CLI options to override connection settings" do
      run_command(Factorix::CLI::Commands::RCon::Exec, %w[--host rconserver --port 25575 --password secret /server-save])

      expect(RCon::Client).to have_received(:open).with("rconserver", 25575, password: "secret", sentinel_command: "/c")
    end

    context "when the server returns output" do
      before { allow(rcon_client).to receive(:execute).and_return("saved") }

      it "prints the output" do
        result = run_command(Factorix::CLI::Commands::RCon::Exec, %w[/server-save])

        expect(result.stdout).to include("saved")
      end
    end

    context "when the server returns no output" do
      it "prints nothing" do
        result = run_command(Factorix::CLI::Commands::RCon::Exec, %w[/server-save])

        expect(result.stdout).to eq("")
      end
    end

    context "when the connection fails" do
      before { allow(RCon::Client).to receive(:open).and_raise(RCon::Client::ConnectionError, "connection refused") }

      it "raises RConConnectionError" do
        expect {
          run_command(Factorix::CLI::Commands::RCon::Exec, %w[/server-save])
        }.to raise_error(Factorix::RConConnectionError, "connection refused")
      end
    end

    context "when authentication fails" do
      before { allow(RCon::Client).to receive(:open).and_raise(RCon::Client::AuthenticationError, "bad password") }

      it "raises RConAuthenticationError" do
        expect {
          run_command(Factorix::CLI::Commands::RCon::Exec, %w[/server-save])
        }.to raise_error(Factorix::RConAuthenticationError, "bad password")
      end
    end
  end
end
