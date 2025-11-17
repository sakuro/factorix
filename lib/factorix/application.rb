# frozen_string_literal: true

require "dry-configurable"
require "dry-container"
require "dry/logger"

module Factorix
  # Application container and configuration
  #
  # Provides dependency injection container and configuration management
  # using dry-container and dry-configurable.
  #
  # @example Configure the application
  #   Factorix::Application.configure do |config|
  #     config.log_level = :debug
  #     config.http.connect_timeout = 10
  #   end
  #
  # @example Resolve dependencies
  #   runtime = Factorix::Application[:runtime]
  class Application
    extend Dry::Container::Mixin
    extend Dry::Configurable

    # Some items are registered with memoize: false to support parallel downloads.
    # Items registered with memoize: false:
    # - :download_http_client
    # - :api_http_client
    # - :downloader
    # - :mod_download_api
    # - :portal

    # Register runtime detector
    register(:runtime, memoize: true) do
      Factorix::Runtime.detect
    end

    # Register logger
    register(:logger, memoize: true) do
      runtime = resolve(:runtime)
      log_path = runtime.factorix_log_path

      # Ensure log directory exists
      log_path.dirname.mkpath unless log_path.dirname.exist?

      # Create logger with file backend
      # Dispatcher level set to DEBUG to allow all messages through
      # Backend controls filtering based on --log-level option
      Dry.Logger(:factorix, level: :debug) do |dispatcher|
        dispatcher.add_backend(
          level: config.log_level,
          stream: log_path.to_s,
          template: "[%<time>s] %<severity>s: %<message>s %<payload>s"
        )
      end
    end

    # Register retry strategy for network operations
    register(:retry_strategy, memoize: true) do
      Factorix::HTTP::RetryStrategy.new
    end

    # Register download cache
    register(:download_cache, memoize: true) do
      Factorix::Cache::FileSystem.new(
        config.cache.download.dir,
        ttl: config.cache.download.ttl,
        max_file_size: config.cache.download.max_file_size
      )
    end

    # Register API cache
    register(:api_cache, memoize: true) do
      Factorix::Cache::FileSystem.new(
        config.cache.api.dir,
        ttl: config.cache.api.ttl,
        max_file_size: config.cache.api.max_file_size
      )
    end

    # Register base HTTP client
    register(:http_client, memoize: true) do
      Factorix::HTTP::Client.new
    end

    # Register decorated HTTP client for downloads (with retry only)
    # Note: Caching is handled by Downloader, not at HTTP client level
    register(:download_http_client, memoize: false) do
      client = resolve(:http_client)
      retry_strategy = resolve(:retry_strategy)

      # Decorate: Client -> Retry (no cache, handled by Downloader)
      Factorix::HTTP::RetryDecorator.new(client:, retry_strategy:)
    end

    # Register decorated HTTP client for API calls (with retry + cache)
    register(:api_http_client, memoize: false) do
      client = resolve(:http_client)
      api_cache = resolve(:api_cache)
      retry_strategy = resolve(:retry_strategy)

      # Decorate: Client -> Cache -> Retry
      cached = Factorix::HTTP::CacheDecorator.new(client:, cache: api_cache)
      Factorix::HTTP::RetryDecorator.new(client: cached, retry_strategy:)
    end

    # Register decorated HTTP client for uploads (with retry only, no cache)
    register(:upload_http_client, memoize: false) do
      client = resolve(:http_client)
      retry_strategy = resolve(:retry_strategy)

      # Decorate: Client -> Retry (no cache for uploads)
      Factorix::HTTP::RetryDecorator.new(client:, retry_strategy:)
    end

    # Register downloader
    register(:downloader, memoize: false) do
      Factorix::Transfer::Downloader.new
    end

    # Register uploader
    register(:uploader, memoize: true) do
      Factorix::Transfer::Uploader.new
    end

    # Register service credential
    register(:service_credential, memoize: true) do
      runtime = resolve(:runtime)
      case config.credential.source
      when :env
        Factorix::ServiceCredential.from_env
      when :player_data
        Factorix::ServiceCredential.from_player_data(runtime:)
      else
        raise ArgumentError, "Invalid credential source: #{config.credential.source}"
      end
    end

    # Register mod portal API client
    register(:mod_portal_api, memoize: true) do
      Factorix::API::MODPortalAPI.new
    end

    # Register mod download API client
    register(:mod_download_api, memoize: false) do
      Factorix::API::MODDownloadAPI.new
    end

    # Register API credential (for mod upload/management)
    register(:api_credential, memoize: true) do
      Factorix::APICredential.from_env
    end

    # Register mod management API client
    register(:mod_management_api, memoize: true) do
      Factorix::API::MODManagementAPI.new
    end

    # Register portal (high-level API wrapper)
    register(:portal, memoize: false) do
      Factorix::Portal.new
    end

    # Log level (:debug, :info, :warn, :error, :fatal)
    setting :log_level, default: :info

    # Credential settings
    setting :credential do
      setting :source, default: :player_data # :player_data or :env
    end

    # Runtime settings (optional overrides for auto-detection)
    setting :runtime do
      setting :executable_path, constructor: ->(v) { v ? Pathname(v) : nil }
      setting :user_dir, constructor: ->(v) { v ? Pathname(v) : nil }
      setting :data_dir, constructor: ->(v) { v ? Pathname(v) : nil }
    end

    # HTTP timeout settings
    setting :http do
      setting :connect_timeout, default: 5
      setting :read_timeout, default: 30
      setting :write_timeout, default: 30
    end

    # Cache settings
    setting :cache do
      # Download cache settings (for MOD files)
      setting :download do
        setting :dir, constructor: ->(value) { Pathname(value) }
        setting :ttl, default: nil # nil for unlimited (MOD files are immutable)
        setting :max_file_size, default: nil # nil for unlimited
      end

      # API cache settings (for API responses)
      setting :api do
        setting :dir, constructor: ->(value) { Pathname(value) }
        setting :ttl, default: 3600 # 1 hour (API responses may change)
        setting :max_file_size, default: 10 * 1024 * 1024 # 10MB (JSON responses)
      end
    end

    # Load configuration from file
    #
    # @param path [Pathname, String, nil] configuration file path
    # @return [void]
    # @raise [Errno::ENOENT] if explicitly specified path does not exist
    def self.load_config(path=nil)
      if path
        # Explicitly specified path must exist
        config_path = Pathname(path)
        raise Errno::ENOENT, config_path.to_s unless config_path.exist?
      else
        # Default path is optional
        config_path = resolve(:runtime).factorix_config_path
        return unless config_path.exist?
      end

      instance_eval(config_path.read, config_path.to_s)
    end

    # Set default values that depend on runtime
    runtime = resolve(:runtime)
    config.cache.download.dir = runtime.factorix_cache_dir / "download"
    config.cache.api.dir = runtime.factorix_cache_dir / "api"
  end
end
