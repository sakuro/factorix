# frozen_string_literal: true

require "json"

RSpec.describe Factorix::ServiceCredential do
  describe ".load" do
    let(:runtime) { instance_double(Factorix::Runtime::Base) }
    let(:player_data_path) { instance_double(Pathname) }

    before do
      allow(Factorix::Container).to receive(:[]).with(:runtime).and_return(runtime)
      allow(Factorix::Container).to receive(:[]).with("logger").and_call_original
    end

    context "when both environment variables are set" do
      before do
        allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("env_user")
        allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("env_token")
      end

      it "loads credentials from environment variables" do
        credential = Factorix::ServiceCredential.load
        expect(credential.username).to eq("env_user")
        expect(credential.token).to eq("env_token")
      end
    end

    context "when only FACTORIO_USERNAME is set" do
      before do
        allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("env_user")
        allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return(nil)
      end

      it "raises CredentialError for partial configuration" do
        expect { Factorix::ServiceCredential.load }.to raise_error(
          Factorix::CredentialError,
          "Both FACTORIO_USERNAME and FACTORIO_TOKEN must be set (or neither)"
        )
      end
    end

    context "when only FACTORIO_TOKEN is set" do
      before do
        allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return(nil)
        allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("env_token")
      end

      it "raises CredentialError for partial configuration" do
        expect { Factorix::ServiceCredential.load }.to raise_error(
          Factorix::CredentialError,
          "Both FACTORIO_USERNAME and FACTORIO_TOKEN must be set (or neither)"
        )
      end
    end

    context "when neither environment variable is set" do
      before do
        allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return(nil)
        allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return(nil)
        allow(runtime).to receive(:player_data_path).and_return(player_data_path)
      end

      it "loads credentials from player-data.json" do
        player_data = {
          "service-username" => "json_user",
          "service-token" => "json_token"
        }
        allow(player_data_path).to receive(:read).and_return(JSON.generate(player_data))

        credential = Factorix::ServiceCredential.load
        expect(credential.username).to eq("json_user")
        expect(credential.token).to eq("json_token")
      end

      it "raises CredentialError when service-username is missing in player-data.json" do
        player_data = {"service-token" => "json_token"}
        allow(player_data_path).to receive(:read).and_return(JSON.generate(player_data))

        expect { Factorix::ServiceCredential.load }.to raise_error(
          Factorix::CredentialError,
          "service-username is missing in player-data.json"
        )
      end

      it "raises CredentialError when service-username is empty in player-data.json" do
        player_data = {"service-username" => "", "service-token" => "json_token"}
        allow(player_data_path).to receive(:read).and_return(JSON.generate(player_data))

        expect { Factorix::ServiceCredential.load }.to raise_error(
          Factorix::CredentialError,
          "service-username is empty in player-data.json"
        )
      end

      it "raises CredentialError when service-token is missing in player-data.json" do
        player_data = {"service-username" => "json_user"}
        allow(player_data_path).to receive(:read).and_return(JSON.generate(player_data))

        expect { Factorix::ServiceCredential.load }.to raise_error(
          Factorix::CredentialError,
          "service-token is missing in player-data.json"
        )
      end

      it "raises CredentialError when service-token is empty in player-data.json" do
        player_data = {"service-username" => "json_user", "service-token" => ""}
        allow(player_data_path).to receive(:read).and_return(JSON.generate(player_data))

        expect { Factorix::ServiceCredential.load }.to raise_error(
          Factorix::CredentialError,
          "service-token is empty in player-data.json"
        )
      end

      it "raises Errno::ENOENT when player-data.json does not exist" do
        allow(player_data_path).to receive(:read).and_raise(Errno::ENOENT)

        expect { Factorix::ServiceCredential.load }.to raise_error(Errno::ENOENT)
      end
    end

    context "when environment variables are set but empty" do
      before do
        allow(runtime).to receive(:player_data_path).and_return(player_data_path)
      end

      it "raises CredentialError when FACTORIO_USERNAME is empty" do
        allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("")
        allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("env_token")

        expect { Factorix::ServiceCredential.load }.to raise_error(
          Factorix::CredentialError,
          "FACTORIO_USERNAME environment variable is empty"
        )
      end

      it "raises CredentialError when FACTORIO_TOKEN is empty" do
        allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("env_user")
        allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("")

        expect { Factorix::ServiceCredential.load }.to raise_error(
          Factorix::CredentialError,
          "FACTORIO_TOKEN environment variable is empty"
        )
      end
    end
  end

  describe "#inspect" do
    before do
      allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("test_user")
      allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("secret_token")
    end

    it "masks both username and token values" do
      credential = Factorix::ServiceCredential.load
      expect(credential.inspect).not_to include("test_user")
      expect(credential.inspect).not_to include("secret_token")
      expect(credential.inspect).to include("*****")
    end
  end

  describe "#to_s" do
    before do
      allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("test_user")
      allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("secret_token")
    end

    it "masks both username and token values" do
      credential = Factorix::ServiceCredential.load
      expect(credential.to_s).not_to include("test_user")
      expect(credential.to_s).not_to include("secret_token")
      expect(credential.to_s).to include("*****")
    end
  end

  describe "#pretty_print" do
    before do
      allow(ENV).to receive(:fetch).with("FACTORIO_USERNAME", nil).and_return("test_user")
      allow(ENV).to receive(:fetch).with("FACTORIO_TOKEN", nil).and_return("secret_token")
    end

    it "masks both username and token values" do
      credential = Factorix::ServiceCredential.load
      output = PP.pp(credential, +"")
      expect(output).not_to include("test_user")
      expect(output).not_to include("secret_token")
      expect(output).to include("*****")
    end
  end
end
