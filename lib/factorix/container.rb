# frozen_string_literal: true

require "dry/core"
require "dry/logger"

module Factorix
  # DI container for dependency injection
  #
  # Provides dependency injection container using dry-core's Container.
  #
  # @example Resolve dependencies
  #   runtime = Factorix::Container[:runtime]
  class Container
    extend Dry::Core::Container::Mixin

    # Some items are registered with memoize: false to support independent event handlers
    # for each parallel download task (e.g., progress tracking).
    # Items registered with memoize: false:
    # - :downloader (event handlers for progress tracking)
    # - :mod_download_api (contains :downloader)
    # - :portal (contains :mod_download_api)

    # Register runtime detector
    register(:runtime, memoize: true) do
      Runtime.detect
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
        dispatcher.add_backend(level: Factorix.config.log_level, stream: log_path.to_s, template: "[%<time>s] %<severity>s: %<message>s %<payload>s")
      end
    end

    # Register retry strategy for network operations
    register(:retry_strategy, memoize: true) do
      HTTP::RetryStrategy.new
    end

    # Register download cache
    register(:download_cache, memoize: true) do
      c = Factorix.config.cache.download
      Cache::FileSystem.new(c.dir, **c.to_h.except(:dir))
    end

    # Register API cache (with compression for JSON responses)
    register(:api_cache, memoize: true) do
      c = Factorix.config.cache.api
      Cache::FileSystem.new(c.dir, **c.to_h.except(:dir))
    end

    # Register info.json cache (for MOD metadata from ZIP files)
    register(:info_json_cache, memoize: true) do
      c = Factorix.config.cache.info_json
      Cache::FileSystem.new(c.dir, **c.to_h.except(:dir))
    end

    # Register base HTTP client
    register(:http_client, memoize: true) do
      HTTP::Client.new(masked_params: %w[username token secure])
    end

    # Register decorated HTTP client for downloads (with retry only)
    # Note: Caching is handled by Downloader, not at HTTP client level
    register(:download_http_client, memoize: true) do
      client = resolve(:http_client)
      retry_strategy = resolve(:retry_strategy)

      # Decorate: Client -> Retry (no cache, handled by Downloader)
      HTTP::RetryDecorator.new(client:, retry_strategy:)
    end

    # Register decorated HTTP client for API calls (with retry + cache)
    register(:api_http_client, memoize: true) do
      client = resolve(:http_client)
      api_cache = resolve(:api_cache)
      retry_strategy = resolve(:retry_strategy)

      # Decorate: Client -> Cache -> Retry
      cached = HTTP::CacheDecorator.new(client:, cache: api_cache)
      HTTP::RetryDecorator.new(client: cached, retry_strategy:)
    end

    # Register decorated HTTP client for uploads (with retry only, no cache)
    register(:upload_http_client, memoize: true) do
      client = resolve(:http_client)
      retry_strategy = resolve(:retry_strategy)

      # Decorate: Client -> Retry (no cache for uploads)
      HTTP::RetryDecorator.new(client:, retry_strategy:)
    end

    # Register downloader
    register(:downloader, memoize: false) do
      Transfer::Downloader.new
    end

    # Register uploader
    register(:uploader, memoize: true) do
      Transfer::Uploader.new
    end

    # Register service credential
    register(:service_credential, memoize: true) { ServiceCredential.load }

    # Register MOD Portal API client
    register(:mod_portal_api, memoize: true) do
      API::MODPortalAPI.new
    end

    # Register MOD Download API client
    register(:mod_download_api, memoize: false) do
      API::MODDownloadAPI.new
    end

    # Register API credential (for MOD upload/management)
    register(:api_credential, memoize: true) { APICredential.load }

    # Register MOD Management API client
    register(:mod_management_api, memoize: true) do
      api = API::MODManagementAPI.new
      # Subscribe mod_portal_api to invalidate cache when MOD is changed on portal
      api.subscribe(resolve(:mod_portal_api))
      api
    end

    # Register portal (high-level API wrapper)
    register(:portal, memoize: false) do
      Portal.new
    end
  end
end
