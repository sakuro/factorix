# frozen_string_literal: true

RSpec.describe Factorix::APICredential do
  describe ".from_env" do
    it "loads api_key from FACTORIO_API_KEY environment variable" do
      allow(ENV).to receive(:fetch).with("FACTORIO_API_KEY", nil).and_return("env_key")

      credential = Factorix::APICredential.from_env
      expect(credential.api_key).to eq("env_key")
    end

    it "raises ArgumentError when environment variable is not set" do
      allow(ENV).to receive(:fetch).with("FACTORIO_API_KEY", nil).and_return(nil)

      expect { Factorix::APICredential.from_env }.to raise_error(ArgumentError, "api_key must not be nil")
    end

    it "raises ArgumentError when environment variable is empty" do
      allow(ENV).to receive(:fetch).with("FACTORIO_API_KEY", nil).and_return("")

      expect { Factorix::APICredential.from_env }.to raise_error(ArgumentError, "api_key must not be empty")
    end
  end
end
