# frozen_string_literal: true

require "pathname"
require_relative "../../lib/factorix/credential"

RSpec.describe Factorix::Credential do
  let(:credential) { Factorix::Credential.new }
  let(:runtime) { instance_double(Factorix::Runtime) }
  let(:player_data_path) { Pathname("path/to/player-data.json") }
  let(:player_data_content) do
    {
      "service-username" => "json-username",
      "service-token" => "json-token"
    }.to_json
  end

  before do
    allow(Factorix::Runtime).to receive(:runtime).and_return(runtime)
    allow(runtime).to receive(:player_data_path).and_return(player_data_path)
    allow(player_data_path).to receive(:read).and_return(player_data_content)
  end

  shared_examples "when player-data.json does not exist" do
    before do
      allow(player_data_path).to receive(:read).and_raise(Errno::ENOENT.new("No such file or directory"))
    end

    context "when environment variable is not set" do
      before do
        ENV.delete(env_name)
      end

      it "raises Errno::ENOENT" do
        expect { subject }.to raise_error(Errno::ENOENT, /No such file or directory/)
      end
    end

    context "when environment variable is empty" do
      before do
        ENV[env_name] = ""
      end

      after do
        ENV.delete(env_name)
      end

      it "raises Errno::ENOENT" do
        expect { subject }.to raise_error(Errno::ENOENT, /No such file or directory/)
      end
    end

    context "when environment variable is set" do
      before do
        ENV[env_name] = env_value
      end

      after do
        ENV.delete(env_name)
      end

      it "returns value from environment variable" do
        expect(subject).to eq env_value
      end
    end
  end

  describe "#username" do
    subject(:username) { credential.username }

    context "when environment variable is not set" do
      before do
        ENV.delete("FACTORIO_SERVICE_USERNAME")
      end

      it "returns username from player-data.json" do
        expect(username).to eq "json-username"
      end
    end

    context "when environment variable is empty" do
      before do
        ENV["FACTORIO_SERVICE_USERNAME"] = ""
      end

      after do
        ENV.delete("FACTORIO_SERVICE_USERNAME")
      end

      it "returns username from player-data.json" do
        expect(username).to eq "json-username"
      end
    end

    context "when environment variable is set" do
      before do
        ENV["FACTORIO_SERVICE_USERNAME"] = "env-username"
      end

      after do
        ENV.delete("FACTORIO_SERVICE_USERNAME")
      end

      it "returns username from environment variable" do
        expect(username).to eq "env-username"
      end
    end

    context "when username is missing in player-data.json" do
      let(:player_data_content) do
        {
          "service-token" => "json-token"
        }.to_json
      end

      before do
        ENV.delete("FACTORIO_SERVICE_USERNAME")
      end

      it "raises KeyError" do
        expect { username }.to raise_error(KeyError, /service-username/)
      end
    end

    context "when player-data.json does not exist" do
      let(:env_name) { "FACTORIO_SERVICE_USERNAME" }
      let(:env_value) { "env-username" }

      include_examples "when player-data.json does not exist"
    end
  end

  describe "#token" do
    subject(:token) { credential.token }

    context "when environment variable is not set" do
      before do
        ENV.delete("FACTORIO_SERVICE_TOKEN")
      end

      it "returns token from player-data.json" do
        expect(token).to eq "json-token"
      end
    end

    context "when environment variable is empty" do
      before do
        ENV["FACTORIO_SERVICE_TOKEN"] = ""
      end

      after do
        ENV.delete("FACTORIO_SERVICE_TOKEN")
      end

      it "returns token from player-data.json" do
        expect(token).to eq "json-token"
      end
    end

    context "when environment variable is set" do
      before do
        ENV["FACTORIO_SERVICE_TOKEN"] = "env-token"
      end

      after do
        ENV.delete("FACTORIO_SERVICE_TOKEN")
      end

      it "returns token from environment variable" do
        expect(token).to eq "env-token"
      end
    end

    context "when token is missing in player-data.json" do
      let(:player_data_content) do
        {
          "service-username" => "json-username"
        }.to_json
      end

      before do
        ENV.delete("FACTORIO_SERVICE_TOKEN")
      end

      it "raises KeyError" do
        expect { token }.to raise_error(KeyError, /service-token/)
      end
    end

    context "when player-data.json does not exist" do
      let(:env_name) { "FACTORIO_SERVICE_TOKEN" }
      let(:env_value) { "env-token" }

      include_examples "when player-data.json does not exist"
    end
  end
end
