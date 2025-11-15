# frozen_string_literal: true

RSpec.describe Factorix::API::MODDownloadAPI do
  let(:service_credential) { instance_double(Factorix::ServiceCredential, username: "test_user", token: "test_token") }
  let(:downloader) { instance_double(Factorix::Transfer::Downloader) }
  let(:api) { Factorix::API::MODDownloadAPI.new(downloader:) }
  let(:download_url) { "/download/example-mod/abc123" }
  let(:output) { Pathname("/tmp/example-mod.zip") }

  before do
    # Stub service_credential in Application container for lazy loading
    allow(Factorix::Application).to receive(:[]).and_call_original
    allow(Factorix::Application).to receive(:[]).with(:service_credential).and_return(service_credential)
  end

  describe "#download" do
    before do
      allow(downloader).to receive(:download)
    end

    it "downloads the mod file via downloader" do
      api.download(download_url, output)
      expect(downloader).to have_received(:download).with(kind_of(URI::HTTPS), output)
    end

    it "builds correct URI with authentication parameters" do
      api.download(download_url, output)

      expect(downloader).to have_received(:download) do |uri, _output|
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
