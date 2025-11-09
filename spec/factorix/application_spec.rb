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

    describe "[:mod_list_api]" do
      it "resolves to an API::MODListAPI instance" do
        mod_list_api = Factorix::Application[:mod_list_api]
        expect(mod_list_api).to be_a(Factorix::API::MODListAPI)
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
