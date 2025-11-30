# frozen_string_literal: true

RSpec.describe Factorix::APICredential do
  describe ".load" do
    it "loads api_key from FACTORIO_API_KEY environment variable" do
      allow(ENV).to receive(:fetch).with("FACTORIO_API_KEY", nil).and_return("env_key")

      credential = Factorix::APICredential.load
      expect(credential.api_key).to eq("env_key")
    end

    it "raises ArgumentError when environment variable is not set" do
      allow(ENV).to receive(:fetch).with("FACTORIO_API_KEY", nil).and_return(nil)

      expect { Factorix::APICredential.load }.to raise_error(ArgumentError, "FACTORIO_API_KEY environment variable is not set")
    end

    it "raises ArgumentError when environment variable is empty" do
      allow(ENV).to receive(:fetch).with("FACTORIO_API_KEY", nil).and_return("")

      expect { Factorix::APICredential.load }.to raise_error(ArgumentError, "FACTORIO_API_KEY environment variable is empty")
    end
  end
end
