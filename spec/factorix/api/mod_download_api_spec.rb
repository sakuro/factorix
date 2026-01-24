# frozen_string_literal: true

RSpec.describe Factorix::API::MODDownloadAPI do
  let(:service_credential) { instance_double(Factorix::ServiceCredential, username: "test_user", token: "test_token") }
  let(:downloader) { instance_double(Factorix::Transfer::Downloader) }
  let(:api) { Factorix::API::MODDownloadAPI.new }
  let(:download_url) { "/download/example-mod/abc123" }
  let(:output) { Pathname("/tmp/example-mod.zip") }

  before do
    # Stub Container to return our mocks
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:service_credential).and_return(service_credential)
    allow(Factorix::Container).to receive(:[]).with(:downloader).and_return(downloader)
    allow(downloader).to receive(:subscribe)
    allow(downloader).to receive(:unsubscribe)
  end

  describe "#download" do
    before do
      allow(downloader).to receive(:download)
    end

    it "downloads the MOD file via downloader" do
      api.download(download_url, output)
      expect(downloader).to have_received(:download).with(kind_of(URI::HTTPS), output, expected_sha1: nil)
    end

    it "passes expected_sha1 to downloader" do
      api.download(download_url, output, expected_sha1: "abc123sha1")
      expect(downloader).to have_received(:download).with(kind_of(URI::HTTPS), output, expected_sha1: "abc123sha1")
    end

    it "builds correct URI with authentication parameters" do
      api.download(download_url, output)

      expect(downloader).to have_received(:download) do |uri, _output, **_opts|
        expect(uri.to_s).to eq("https://mods.factorio.com/download/example-mod/abc123?username=test_user&token=test_token")
      end
    end

    context "with invalid download_url" do
      it "raises ArgumentError if download_url does not start with '/'" do
        expect {
          api.download("https://example.com/download", output)
        }.to raise_error(ArgumentError, "download_url must be a relative path starting with '/'")
      end

      it "raises ArgumentError for relative path without leading slash" do
        expect {
          api.download("download/example-mod/abc123", output)
        }.to raise_error(ArgumentError, "download_url must be a relative path starting with '/'")
      end
    end
  end
end
