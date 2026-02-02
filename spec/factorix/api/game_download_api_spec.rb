# frozen_string_literal: true

RSpec.describe Factorix::API::GameDownloadAPI do
  let(:logger) { instance_double(Dry::Logger::Dispatcher, debug: nil) }
  let(:client) { instance_double(Factorix::HTTP::Client) }
  let(:service_credential) { instance_double(Factorix::ServiceCredential, username: "test_user", token: "test_token") }
  let(:downloader) { instance_double(Factorix::Transfer::Downloader) }
  let(:api) { Factorix::API::GameDownloadAPI.new(logger:, client:) }

  before do
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:service_credential).and_return(service_credential)
    allow(Factorix::Container).to receive(:[]).with(:downloader).and_return(downloader)
    allow(downloader).to receive(:subscribe)
    allow(downloader).to receive(:unsubscribe)
  end

  describe "#latest_releases" do
    let(:releases_json) do
      {
        stable: {alpha: "2.0.28", expansion: "2.0.28", headless: "2.0.28"},
        experimental: {alpha: "2.0.29", expansion: "2.0.29", headless: "2.0.29"}
      }.to_json
    end

    before do
      response = instance_double(Factorix::HTTP::Response, body: releases_json)
      allow(client).to receive(:get).and_return(response)
    end

    it "fetches latest releases from API" do
      api.latest_releases

      expect(client).to have_received(:get).with(URI("https://factorio.com/api/latest-releases"))
    end

    it "returns parsed release information" do
      result = api.latest_releases

      expect(result[:stable][:alpha]).to eq("2.0.28")
      expect(result[:experimental][:alpha]).to eq("2.0.29")
    end
  end

  describe "#latest_version" do
    let(:releases_json) do
      {
        stable: {alpha: "2.0.28", expansion: "2.0.28", headless: "2.0.28"},
        experimental: {alpha: "2.0.29", expansion: "2.0.29", headless: "2.0.29"}
      }.to_json
    end

    before do
      response = instance_double(Factorix::HTTP::Response, body: releases_json)
      allow(client).to receive(:get).and_return(response)
    end

    it "returns stable alpha version" do
      result = api.latest_version(channel: "stable", build: "alpha")

      expect(result).to eq("2.0.28")
    end

    it "returns experimental headless version" do
      result = api.latest_version(channel: "experimental", build: "headless")

      expect(result).to eq("2.0.29")
    end

    it "returns nil for unavailable build" do
      result = api.latest_version(channel: "stable", build: "demo")

      expect(result).to be_nil
    end
  end

  describe "#resolve_filename" do
    let(:final_uri) { URI("https://www.factorio.com/get-download/stable/2.0.28/alpha/osx/Factorio_2.0.28.dmg") }
    let(:response) { instance_double(Factorix::HTTP::Response, uri: final_uri) }

    before do
      allow(client).to receive(:head).and_return(response)
    end

    it "makes HEAD request to download endpoint" do
      api.resolve_filename(version: "2.0.28", build: "alpha", platform: "osx")

      expect(client).to have_received(:head) do |uri|
        expect(uri.host).to eq("www.factorio.com")
        expect(uri.path).to eq("/get-download/2.0.28/alpha/osx")
      end
    end

    it "extracts filename from final redirect URL" do
      result = api.resolve_filename(version: "2.0.28", build: "alpha", platform: "osx")

      expect(result).to eq("Factorio_2.0.28.dmg")
    end

    it "includes authentication parameters in request" do
      api.resolve_filename(version: "2.0.28", build: "alpha", platform: "osx")

      expect(client).to have_received(:head) do |uri|
        expect(uri.query).to include("username=test_user")
        expect(uri.query).to include("token=test_token")
      end
    end

    context "with invalid build type" do
      it "raises ArgumentError" do
        expect {
          api.resolve_filename(version: "2.0.28", build: "invalid", platform: "osx")
        }.to raise_error(ArgumentError, /Invalid build type/)
      end
    end

    context "with invalid platform" do
      it "raises ArgumentError" do
        expect {
          api.resolve_filename(version: "2.0.28", build: "alpha", platform: "invalid")
        }.to raise_error(ArgumentError, /Invalid platform/)
      end
    end
  end

  describe "#download" do
    let(:output) { Pathname("/tmp/Factorio.dmg") }

    before do
      allow(downloader).to receive(:download)
    end

    it "downloads via downloader" do
      api.download(version: "2.0.28", build: "alpha", platform: "osx", output:)

      expect(downloader).to have_received(:download).with(kind_of(URI::HTTPS), output)
    end

    it "builds correct download URI" do
      api.download(version: "2.0.28", build: "alpha", platform: "osx", output:)

      expect(downloader).to have_received(:download) do |uri, _output|
        expect(uri.host).to eq("www.factorio.com")
        expect(uri.path).to eq("/get-download/2.0.28/alpha/osx")
        expect(uri.query).to include("username=test_user")
        expect(uri.query).to include("token=test_token")
      end
    end

    it "subscribes handler when provided" do
      handler = instance_double(Object)

      api.download(version: "2.0.28", build: "alpha", platform: "osx", output:, handler:)

      expect(downloader).to have_received(:subscribe).with(handler)
      expect(downloader).to have_received(:unsubscribe).with(handler)
    end

    it "does not subscribe when handler is nil" do
      api.download(version: "2.0.28", build: "alpha", platform: "osx", output:)

      expect(downloader).not_to have_received(:subscribe)
      expect(downloader).not_to have_received(:unsubscribe)
    end

    context "with invalid build type" do
      it "raises ArgumentError" do
        expect {
          api.download(version: "2.0.28", build: "invalid", platform: "osx", output:)
        }.to raise_error(ArgumentError, /Invalid build type/)
      end
    end

    context "with invalid platform" do
      it "raises ArgumentError" do
        expect {
          api.download(version: "2.0.28", build: "alpha", platform: "invalid", output:)
        }.to raise_error(ArgumentError, /Invalid platform/)
      end
    end
  end

  describe "constants" do
    it "defines valid BUILDS" do
      expect(Factorix::API::GameDownloadAPI::BUILDS).to eq(%w[alpha expansion demo headless])
    end

    it "defines valid PLATFORMS" do
      expect(Factorix::API::GameDownloadAPI::PLATFORMS).to eq(%w[win64 win64-manual osx linux64])
    end

    it "defines valid CHANNELS" do
      expect(Factorix::API::GameDownloadAPI::CHANNELS).to eq(%w[stable experimental])
    end
  end
end
