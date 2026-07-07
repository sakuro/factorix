# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::Container do
  describe "container" do
    describe "[:runtime]" do
      it "resolves to a Runtime instance" do
        runtime = Factorix::Container[:runtime]
        expect(runtime).to be_a(Factorix::Runtime::Base)
      end
    end

    describe "[:logger]" do
      it "resolves to a logger with standard logging interface" do
        logger = Factorix::Container[:logger]
        expect(logger).to respond_to(:debug, :info, :warn, :error, :fatal)
      end

      it "creates log file in XDG_STATE_HOME" do
        skip "Logger is stubbed in spec_helper to prevent file creation during tests"

        runtime = Factorix::Container[:runtime]
        log_path = runtime.factorix_log_path

        # Logger is created lazily, so resolve it
        Factorix::Container[:logger]

        # Log directory should be created
        expect(log_path.dirname).to exist
      end

      it "uses log level from configuration" do
        skip "Difficult to change log level of registered logger and recreate it"

        original_level = Factorix.config.log_level

        Factorix.config.log_level = :debug
        # Force re-registration by calling resolve directly
        logger = Factorix::Container.resolve(:logger)
        expect(logger.level).to eq(Logger::DEBUG)

        Factorix.config.log_level = :warn
        logger = Factorix::Container.resolve(:logger)
        expect(logger.level).to eq(Logger::WARN)

        Factorix.config.log_level = original_level
      end

      it "formats messages with timestamp and severity" do
        logger = Factorix::Container[:logger]
        logger.info("test message")

        expect(log_content).to match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [+-]\d{4}\] INFO: test message/)
      end
    end

    describe "[:download_cache]" do
      it "resolves to a Cache::Base instance" do
        download_cache = Factorix::Container[:download_cache]
        expect(download_cache).to be_a(Factorix::Cache::Base)
      end
    end

    describe "[:api_cache]" do
      it "resolves to a Cache::Base instance" do
        api_cache = Factorix::Container[:api_cache]
        expect(api_cache).to be_a(Factorix::Cache::Base)
      end
    end

    describe "[:http_client]" do
      it "resolves to an HTTP::Client instance" do
        http_client = Factorix::Container[:http_client]
        expect(http_client).to be_a(Factorix::HTTP::Client)
      end
    end

    describe "[:downloader]" do
      it "resolves to a Transfer::Downloader instance" do
        downloader = Factorix::Container[:downloader]
        expect(downloader).to be_a(Factorix::Transfer::Downloader)
      end
    end

    describe "[:uploader]" do
      it "resolves to a Transfer::Uploader instance" do
        uploader = Factorix::Container[:uploader]
        expect(uploader).to be_a(Factorix::Transfer::Uploader)
      end
    end

    describe "[:mod_portal_api]" do
      it "resolves to an API::MODPortalAPI instance" do
        mod_portal_api = Factorix::Container[:mod_portal_api]
        expect(mod_portal_api).to be_a(Factorix::API::MODPortalAPI)
      end
    end

    describe "[:mod_download_api]" do
      before do
        ENV["FACTORIO_USERNAME"] = "test_user"
        ENV["FACTORIO_TOKEN"] = "test_token"
      end

      after do
        ENV.delete("FACTORIO_USERNAME")
        ENV.delete("FACTORIO_TOKEN")
      end

      it "resolves to an API::MODDownloadAPI instance" do
        mod_download_api = Factorix::Container[:mod_download_api]
        expect(mod_download_api).to be_a(Factorix::API::MODDownloadAPI)
      end
    end

    describe "[:service_credential]" do
      before do
        ENV["FACTORIO_USERNAME"] = "test_user"
        ENV["FACTORIO_TOKEN"] = "test_token"
      end

      after do
        ENV.delete("FACTORIO_USERNAME")
        ENV.delete("FACTORIO_TOKEN")
      end

      it "resolves to a ServiceCredential instance" do
        service_credential = Factorix::Container[:service_credential]
        expect(service_credential).to be_a(Factorix::ServiceCredential)
      end
    end

    describe "[:retry_strategy]" do
      it "resolves to an HTTP::RetryStrategy instance" do
        retry_strategy = Factorix::Container[:retry_strategy]
        expect(retry_strategy).to be_a(Factorix::HTTP::RetryStrategy)
      end
    end

    describe "[:download_http_client]" do
      it "provides HTTP client interface" do
        download_http_client = Factorix::Container[:download_http_client]
        expect(download_http_client).to respond_to(:request, :get, :post)
      end
    end

    describe "[:api_http_client]" do
      it "provides HTTP client interface" do
        api_http_client = Factorix::Container[:api_http_client]
        expect(api_http_client).to respond_to(:request, :get, :post)
      end
    end

    describe "[:upload_http_client]" do
      it "provides HTTP client interface" do
        upload_http_client = Factorix::Container[:upload_http_client]
        expect(upload_http_client).to respond_to(:request, :get, :post)
      end
    end

    describe "[:api_credential]" do
      before do
        ENV["FACTORIO_API_KEY"] = "test_api_key"
      end

      after do
        ENV.delete("FACTORIO_API_KEY")
      end

      it "resolves to an APICredential instance" do
        api_credential = Factorix::Container[:api_credential]
        expect(api_credential).to be_a(Factorix::APICredential)
      end
    end

    describe "[:mod_management_api]" do
      it "resolves to an API::MODManagementAPI instance" do
        mod_management_api = Factorix::Container[:mod_management_api]
        expect(mod_management_api).to be_a(Factorix::API::MODManagementAPI)
      end
    end

    describe "[:portal]" do
      before do
        ENV["FACTORIO_USERNAME"] = "test_user"
        ENV["FACTORIO_TOKEN"] = "test_token"
      end

      after do
        ENV.delete("FACTORIO_USERNAME")
        ENV.delete("FACTORIO_TOKEN")
      end

      it "resolves to a Portal instance" do
        portal = Factorix::Container[:portal]
        expect(portal).to be_a(Factorix::Portal)
      end
    end
  end
end
