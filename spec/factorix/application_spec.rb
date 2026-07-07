# frozen_string_literal: true

RSpec.describe Factorix::Application do
  # A fresh application wired to the suite's sandboxed runtime and logger,
  # so component construction does not leak outside the test environment.
  let(:app) do
    application = Factorix::Application.new
    application.runtime = Factorix.app.runtime
    application.logger = Factorix.app.logger
    application
  end

  describe "#runtime" do
    it "detects a platform runtime" do
      expect(Factorix::Application.new.runtime).to be_a(Factorix::Runtime::Base)
    end
  end

  describe "#logger" do
    it "builds a logger writing under the state directory" do
      application = Factorix::Application.new
      application.runtime = Factorix.app.runtime

      logger = application.logger

      expect(logger).to be_a(Factorix::Logger)
      expect(Factorix.app.runtime.factorix_log_path.dirname).to exist
    end

    it "formats messages with timestamp and severity" do
      app.logger.info("test message")

      expect(log_content).to match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [+-]\d{4}\] INFO: test message/)
    end
  end

  describe "#download_cache" do
    it "builds a Cache::Base instance" do
      expect(app.download_cache).to be_a(Factorix::Cache::Base)
    end
  end

  describe "#api_cache" do
    it "builds a Cache::Base instance" do
      expect(app.api_cache).to be_a(Factorix::Cache::Base)
    end
  end

  describe "#http_client" do
    it "builds an HTTP::Client instance" do
      expect(app.http_client).to be_a(Factorix::HTTP::Client)
    end
  end

  describe "#retry_strategy" do
    it "builds an HTTP::RetryStrategy instance" do
      expect(app.retry_strategy).to be_a(Factorix::HTTP::RetryStrategy)
    end
  end

  describe "#download_http_client" do
    it "provides the HTTP client interface" do
      expect(app.download_http_client).to respond_to(:request, :get, :post)
    end
  end

  describe "#api_http_client" do
    it "provides the HTTP client interface" do
      expect(app.api_http_client).to respond_to(:request, :get, :post)
    end
  end

  describe "#upload_http_client" do
    it "provides the HTTP client interface" do
      expect(app.upload_http_client).to respond_to(:request, :get, :post)
    end
  end

  describe "#downloader" do
    it "builds a Transfer::Downloader instance" do
      expect(app.downloader).to be_a(Factorix::Transfer::Downloader)
    end

    it "memoizes the instance" do
      first = app.downloader

      expect(app.downloader).to be(first)
    end
  end

  describe "#uploader" do
    it "builds a Transfer::Uploader instance" do
      expect(app.uploader).to be_a(Factorix::Transfer::Uploader)
    end
  end

  describe "#mod_portal_api" do
    it "builds an API::MODPortalAPI instance" do
      expect(app.mod_portal_api).to be_a(Factorix::API::MODPortalAPI)
    end
  end

  describe "#mod_download_api" do
    it "builds an API::MODDownloadAPI instance" do
      expect(app.mod_download_api).to be_a(Factorix::API::MODDownloadAPI)
    end
  end

  describe "#game_download_api" do
    it "builds an API::GameDownloadAPI instance" do
      expect(app.game_download_api).to be_a(Factorix::API::GameDownloadAPI)
    end
  end

  describe "#mod_management_api" do
    it "builds an API::MODManagementAPI wired to invalidate portal caches" do
      api = app.mod_management_api

      expect(api).to be_a(Factorix::API::MODManagementAPI)
    end
  end

  describe "#portal" do
    before do
      ENV["FACTORIO_USERNAME"] = "test_user"
      ENV["FACTORIO_TOKEN"] = "test_token"
    end

    after do
      ENV.delete("FACTORIO_USERNAME")
      ENV.delete("FACTORIO_TOKEN")
    end

    it "builds a Portal instance" do
      expect(app.portal).to be_a(Factorix::Portal)
    end
  end

  describe "#service_credential" do
    before do
      ENV["FACTORIO_USERNAME"] = "test_user"
      ENV["FACTORIO_TOKEN"] = "test_token"
    end

    after do
      ENV.delete("FACTORIO_USERNAME")
      ENV.delete("FACTORIO_TOKEN")
    end

    it "loads a ServiceCredential" do
      expect(app.service_credential).to be_a(Factorix::ServiceCredential)
    end
  end

  describe "#api_credential" do
    before do
      ENV["FACTORIO_API_KEY"] = "test_api_key"
    end

    after do
      ENV.delete("FACTORIO_API_KEY")
    end

    it "loads an APICredential" do
      expect(app.api_credential).to be_a(Factorix::APICredential)
    end
  end

  describe "writers" do
    it "allows replacing a component before first use" do
      app.downloader = :replaced

      expect(app.downloader).to eq(:replaced)
    end
  end
end
