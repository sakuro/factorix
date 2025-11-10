# frozen_string_literal: true

require "json"

RSpec.describe Factorix::ServiceCredential do
  describe ".from_env" do
    it "loads credentials from environment variables" do
      allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("env_user")
      allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("env_token")

      credential = Factorix::ServiceCredential.from_env
      expect(credential.username).to eq("env_user")
      expect(credential.token).to eq("env_token")
    end

    it "raises ArgumentError when FACTORIO_USERNAME is not set" do
      allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return(nil)
      allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("env_token")

      expect { Factorix::ServiceCredential.from_env }.to raise_error(ArgumentError, "FACTORIO_USERNAME environment variable is not set")
    end

    it "raises ArgumentError when FACTORIO_TOKEN is not set" do
      allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("env_user")
      allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return(nil)

      expect { Factorix::ServiceCredential.from_env }.to raise_error(ArgumentError, "FACTORIO_TOKEN environment variable is not set")
    end

    it "raises ArgumentError when FACTORIO_USERNAME is empty" do
      allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("")
      allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("env_token")

      expect { Factorix::ServiceCredential.from_env }.to raise_error(ArgumentError, "FACTORIO_USERNAME environment variable is empty")
    end

    it "raises ArgumentError when FACTORIO_TOKEN is empty" do
      allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("env_user")
      allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("")

      expect { Factorix::ServiceCredential.from_env }.to raise_error(ArgumentError, "FACTORIO_TOKEN environment variable is empty")
    end
  end

  describe ".from_player_data" do
    let(:runtime) { instance_double(Factorix::Runtime::Base) }
    let(:player_data_path) { instance_double(Pathname) }

    before do
      allow(Factorix::Application).to receive(:[]).with(:runtime).and_return(runtime)
    end

    it "loads credentials from player-data.json" do
      player_data = {
        "service-username" => "json_user",
        "service-token" => "json_token"
      }

      allow(runtime).to receive(:player_data_path).and_return(player_data_path)
      allow(player_data_path).to receive(:read).and_return(JSON.generate(player_data))

      credential = Factorix::ServiceCredential.from_player_data
      expect(credential.username).to eq("json_user")
      expect(credential.token).to eq("json_token")
    end

    it "raises ArgumentError when service-username is missing" do
      player_data = {
        "service-token" => "json_token"
      }

      allow(runtime).to receive(:player_data_path).and_return(player_data_path)
      allow(player_data_path).to receive(:read).and_return(JSON.generate(player_data))

      expect { Factorix::ServiceCredential.from_player_data }.to raise_error(ArgumentError, "service-username is missing in player-data.json")
    end

    it "raises ArgumentError when service-username is empty" do
      player_data = {
        "service-username" => "",
        "service-token" => "json_token"
      }

      allow(runtime).to receive(:player_data_path).and_return(player_data_path)
      allow(player_data_path).to receive(:read).and_return(JSON.generate(player_data))

      expect { Factorix::ServiceCredential.from_player_data }.to raise_error(ArgumentError, "service-username is empty in player-data.json")
    end

    it "raises ArgumentError when service-token is missing" do
      player_data = {
        "service-username" => "json_user"
      }

      allow(runtime).to receive(:player_data_path).and_return(player_data_path)
      allow(player_data_path).to receive(:read).and_return(JSON.generate(player_data))

      expect { Factorix::ServiceCredential.from_player_data }.to raise_error(ArgumentError, "service-token is missing in player-data.json")
    end

    it "raises ArgumentError when service-token is empty" do
      player_data = {
        "service-username" => "json_user",
        "service-token" => ""
      }

      allow(runtime).to receive(:player_data_path).and_return(player_data_path)
      allow(player_data_path).to receive(:read).and_return(JSON.generate(player_data))

      expect { Factorix::ServiceCredential.from_player_data }.to raise_error(ArgumentError, "service-token is empty in player-data.json")
    end

    it "raises Errno::ENOENT when player-data.json does not exist" do
      allow(runtime).to receive(:player_data_path).and_return(player_data_path)
      allow(player_data_path).to receive(:read).and_raise(Errno::ENOENT)

      expect { Factorix::ServiceCredential.from_player_data }.to raise_error(Errno::ENOENT)
    end
  end
end
