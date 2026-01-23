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

  describe "configuration" do
    after do
      # Reset configuration after each test
      Factorix.config.log_level = :info
      Factorix.config.http.connect_timeout = 5
      Factorix.config.http.read_timeout = 30
      Factorix.config.http.write_timeout = 30
    end

    describe ".config" do
      it "provides access to configuration" do
        expect(Factorix.config).to respond_to(:log_level)
        expect(Factorix.config).to respond_to(:cache)
      end
    end

    describe "cache.download" do
      it "has default backend of :file_system" do
        expect(Factorix.config.cache.download.backend).to eq(:file_system)
      end

      it "has default ttl of nil" do
        expect(Factorix.config.cache.download.ttl).to be_nil
      end

      it "has default max_file_size of nil" do
        expect(Factorix.config.cache.download.file_system.max_file_size).to be_nil
      end

      it "can be overridden" do
        custom_path = Pathname("/custom/cache/download")
        Factorix.config.cache.download.file_system.root = custom_path
        expect(Factorix.config.cache.download.file_system.root).to eq(custom_path)
      end
    end

    describe "cache.api" do
      it "has default backend of :file_system" do
        expect(Factorix.config.cache.api.backend).to eq(:file_system)
      end

      it "has default ttl of 3600 seconds" do
        expect(Factorix.config.cache.api.ttl).to eq(3600)
      end

      it "has default max_file_size of 10MiB" do
        expect(Factorix.config.cache.api.file_system.max_file_size).to eq(10 * 1024 * 1024)
      end
    end

    describe "log_level" do
      it "defaults to :info" do
        expect(Factorix.config.log_level).to eq(:info)
      end

      it "can be changed" do
        Factorix.config.log_level = :debug
        expect(Factorix.config.log_level).to eq(:debug)
      end
    end

    describe "http timeouts" do
      it "has default connect_timeout" do
        expect(Factorix.config.http.connect_timeout).to eq(5)
      end

      it "has default read_timeout" do
        expect(Factorix.config.http.read_timeout).to eq(30)
      end

      it "has default write_timeout" do
        expect(Factorix.config.http.write_timeout).to eq(30)
      end

      it "can be changed" do
        Factorix.config.http.connect_timeout = 10
        expect(Factorix.config.http.connect_timeout).to eq(10)
      end
    end

    describe ".configure block" do
      it "allows configuration via block" do
        Factorix.configure do |config|
          config.log_level = :warn
          config.http.connect_timeout = 15
        end

        expect(Factorix.config.log_level).to eq(:warn)
        expect(Factorix.config.http.connect_timeout).to eq(15)
      end
    end

    describe "runtime settings" do
      after do
        Factorix.config.runtime.executable_path = nil
        Factorix.config.runtime.user_dir = nil
        Factorix.config.runtime.data_dir = nil
      end

      it "converts executable_path string to Pathname" do
        Factorix.config.runtime.executable_path = "/path/to/factorio"
        expect(Factorix.config.runtime.executable_path).to eq(Pathname("/path/to/factorio"))
      end

      it "converts user_dir string to Pathname" do
        Factorix.config.runtime.user_dir = "/path/to/user"
        expect(Factorix.config.runtime.user_dir).to eq(Pathname("/path/to/user"))
      end

      it "converts data_dir string to Pathname" do
        Factorix.config.runtime.data_dir = "/path/to/data"
        expect(Factorix.config.runtime.data_dir).to eq(Pathname("/path/to/data"))
      end
    end
  end

  describe ".load_config" do
    let(:config_content) do
      <<~RUBY
        configure do |config|
          config.log_level = :debug
          config.http.connect_timeout = 20
        end
      RUBY
    end

    context "when config file exists" do
      let(:config_file) { Tempfile.new(["factorix_config", ".rb"]) }

      before do
        config_file.write(config_content)
        config_file.close
      end

      after do
        config_file.unlink
        Factorix.config.log_level = :info
        Factorix.config.http.connect_timeout = 5
      end

      it "loads configuration from file" do
        Factorix.load_config(Pathname(config_file.path))

        expect(Factorix.config.log_level).to eq(:debug)
        expect(Factorix.config.http.connect_timeout).to eq(20)
      end
    end

    context "when explicitly specified config file does not exist" do
      it "raises ConfigurationError" do
        expect {
          Factorix.load_config(Pathname("/nonexistent/config.rb"))
        }.to raise_error(Factorix::ConfigurationError, /nonexistent/)
      end
    end

    context "when path is nil" do
      it "tries to load from default path" do
        # Default path likely doesn't exist in test environment
        expect {
          Factorix.load_config(nil)
        }.not_to raise_error
      end
    end
  end
end
