# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::Application do
  describe "container" do
    describe "[:runtime]" do
      it "resolves to a Runtime instance" do
        runtime = Factorix::Application[:runtime]
        expect(runtime).to be_a(Factorix::Runtime::Base)
      end
    end

    describe "[:logger]" do
      it "resolves to a Logger instance" do
        logger = Factorix::Application[:logger]
        expect(logger).to be_a(Logger)
      end

      it "creates log file in XDG_STATE_HOME" do
        runtime = Factorix::Application[:runtime]
        log_path = runtime.factorix_log_path

        # Logger is created lazily, so resolve it
        Factorix::Application[:logger]

        # Log directory should be created
        expect(log_path.dirname).to exist
      end

      it "uses log level from configuration" do
        original_level = Factorix::Application.config.log_level

        Factorix::Application.config.log_level = :debug
        # Force re-registration by calling resolve directly
        logger = Factorix::Application.resolve(:logger)
        expect(logger.level).to eq(Logger::DEBUG)

        Factorix::Application.config.log_level = :warn
        logger = Factorix::Application.resolve(:logger)
        expect(logger.level).to eq(Logger::WARN)

        Factorix::Application.config.log_level = original_level
      end

      it "formats messages with timestamp and severity" do
        runtime = Factorix::Application[:runtime]
        log_path = runtime.factorix_log_path

        logger = Factorix::Application[:logger]
        logger.info("test message")
        logger.close

        # Read log file
        log_content = log_path.read

        expect(log_content).to match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] INFO: test message/)
      end
    end

    describe "[:download_cache]" do
      it "resolves to a Cache::FileSystem instance" do
        download_cache = Factorix::Application[:download_cache]
        expect(download_cache).to be_a(Factorix::Cache::FileSystem)
      end
    end

    describe "[:api_cache]" do
      it "resolves to a Cache::FileSystem instance" do
        api_cache = Factorix::Application[:api_cache]
        expect(api_cache).to be_a(Factorix::Cache::FileSystem)
      end
    end

    describe "[:http]" do
      it "resolves to a Transfer::HTTP instance" do
        http = Factorix::Application[:http]
        expect(http).to be_a(Factorix::Transfer::HTTP)
      end
    end

    describe "[:downloader]" do
      it "resolves to a Transfer::Downloader instance" do
        downloader = Factorix::Application[:downloader]
        expect(downloader).to be_a(Factorix::Transfer::Downloader)
      end
    end

    describe "[:uploader]" do
      it "resolves to a Transfer::Uploader instance" do
        uploader = Factorix::Application[:uploader]
        expect(uploader).to be_a(Factorix::Transfer::Uploader)
      end
    end

    describe "[:mod_portal_api]" do
      it "resolves to an API::MODPortalAPI instance" do
        mod_portal_api = Factorix::Application[:mod_portal_api]
        expect(mod_portal_api).to be_a(Factorix::API::MODPortalAPI)
      end
    end

    describe "[:mod_download_api]" do
      before do
        # Use environment-based credentials to avoid NotImplementedError on plain Linux
        Factorix::Application.config.credential.source = :env
        ENV["FACTORIO_USERNAME"] = "test_user"
        ENV["FACTORIO_TOKEN"] = "test_token"
      end

      after do
        Factorix::Application.config.credential.source = :player_data
        ENV.delete("FACTORIO_USERNAME")
        ENV.delete("FACTORIO_TOKEN")
      end

      it "resolves to an API::MODDownloadAPI instance" do
        mod_download_api = Factorix::Application[:mod_download_api]
        expect(mod_download_api).to be_a(Factorix::API::MODDownloadAPI)
      end
    end

    describe "[:service_credential]" do
      before do
        # Use environment-based credentials to avoid NotImplementedError on plain Linux
        Factorix::Application.config.credential.source = :env
        ENV["FACTORIO_USERNAME"] = "test_user"
        ENV["FACTORIO_TOKEN"] = "test_token"
      end

      after do
        Factorix::Application.config.credential.source = :player_data
        ENV.delete("FACTORIO_USERNAME")
        ENV.delete("FACTORIO_TOKEN")
      end

      it "resolves to a ServiceCredential instance" do
        service_credential = Factorix::Application[:service_credential]
        expect(service_credential).to be_a(Factorix::ServiceCredential)
      end
    end
  end

  describe "configuration" do
    after do
      # Reset configuration after each test
      Factorix::Application.config.log_level = :info
      Factorix::Application.config.http.connect_timeout = 5
      Factorix::Application.config.http.read_timeout = 30
      Factorix::Application.config.http.write_timeout = 30
    end

    describe ".config" do
      it "provides access to configuration" do
        expect(Factorix::Application.config).to respond_to(:log_level)
        expect(Factorix::Application.config).to respond_to(:cache)
      end
    end

    describe "cache.download" do
      it "defaults dir to runtime.factorix_cache_dir/download" do
        runtime = Factorix::Application[:runtime]
        expect(Factorix::Application.config.cache.download.dir).to eq(runtime.factorix_cache_dir / "download")
      end

      it "has default ttl of nil" do
        expect(Factorix::Application.config.cache.download.ttl).to be_nil
      end

      it "has default max_file_size of nil" do
        expect(Factorix::Application.config.cache.download.max_file_size).to be_nil
      end

      it "can be overridden" do
        custom_path = Pathname("/custom/cache/download")
        Factorix::Application.config.cache.download.dir = custom_path
        expect(Factorix::Application.config.cache.download.dir).to eq(custom_path)
      end
    end

    describe "cache.api" do
      it "defaults dir to runtime.factorix_cache_dir/api" do
        runtime = Factorix::Application[:runtime]
        expect(Factorix::Application.config.cache.api.dir).to eq(runtime.factorix_cache_dir / "api")
      end

      it "has default ttl of 3600 seconds" do
        expect(Factorix::Application.config.cache.api.ttl).to eq(3600)
      end

      it "has default max_file_size of 1MB" do
        expect(Factorix::Application.config.cache.api.max_file_size).to eq(1024 * 1024)
      end
    end

    describe "log_level" do
      it "defaults to :info" do
        expect(Factorix::Application.config.log_level).to eq(:info)
      end

      it "can be changed" do
        Factorix::Application.config.log_level = :debug
        expect(Factorix::Application.config.log_level).to eq(:debug)
      end
    end

    describe "http timeouts" do
      it "has default connect_timeout" do
        expect(Factorix::Application.config.http.connect_timeout).to eq(5)
      end

      it "has default read_timeout" do
        expect(Factorix::Application.config.http.read_timeout).to eq(30)
      end

      it "has default write_timeout" do
        expect(Factorix::Application.config.http.write_timeout).to eq(30)
      end

      it "can be changed" do
        Factorix::Application.config.http.connect_timeout = 10
        expect(Factorix::Application.config.http.connect_timeout).to eq(10)
      end
    end

    describe ".configure block" do
      it "allows configuration via block" do
        Factorix::Application.configure do |config|
          config.log_level = :warn
          config.http.connect_timeout = 15
        end

        expect(Factorix::Application.config.log_level).to eq(:warn)
        expect(Factorix::Application.config.http.connect_timeout).to eq(15)
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
        Factorix::Application.config.log_level = :info
        Factorix::Application.config.http.connect_timeout = 5
      end

      it "loads configuration from file" do
        Factorix::Application.load_config(config_file.path)

        expect(Factorix::Application.config.log_level).to eq(:debug)
        expect(Factorix::Application.config.http.connect_timeout).to eq(20)
      end
    end

    context "when explicitly specified config file does not exist" do
      it "raises Errno::ENOENT" do
        expect {
          Factorix::Application.load_config("/nonexistent/config.rb")
        }.to raise_error(Errno::ENOENT, /nonexistent/)
      end
    end

    context "when path is nil" do
      it "tries to load from default path" do
        # Default path likely doesn't exist in test environment
        expect {
          Factorix::Application.load_config(nil)
        }.not_to raise_error
      end
    end
  end
end
