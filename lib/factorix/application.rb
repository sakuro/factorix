# frozen_string_literal: true

module Factorix
  # Composition root wiring the application object graph
  #
  # Each component is memoized on first access. Writers allow tests (and
  # alternative wiring) to replace a component before its first use.
  # Access the shared instance via Factorix.app.
  class Application
    CACHE_BACKENDS = {
      file_system: -> { Cache::FileSystem },
      redis: -> { Cache::Redis },
      s3: -> { Cache::S3 }
    }.freeze
    private_constant :CACHE_BACKENDS

    attr_writer :runtime
    attr_writer :logger
    attr_writer :retry_strategy
    attr_writer :download_cache
    attr_writer :api_cache
    attr_writer :info_json_cache
    attr_writer :http_client
    attr_writer :download_http_client
    attr_writer :api_http_client
    attr_writer :upload_http_client
    attr_writer :downloader
    attr_writer :uploader
    attr_writer :service_credential
    attr_writer :api_credential
    attr_writer :mod_portal_api
    attr_writer :mod_download_api
    attr_writer :game_download_api
    attr_writer :mod_management_api
    attr_writer :portal

    # @return [Runtime::Base] platform runtime
    def runtime = @runtime ||= Runtime.detect

    # @return [Logger] application logger writing to the platform log path
    def logger
      @logger ||= begin
        log_path = runtime.factorix_log_path
        log_path.dirname.mkpath unless log_path.dirname.exist?
        Logger.new(log_path, level: Factorix.config.log_level)
      end
    end

    # @return [HTTP::RetryStrategy] retry strategy for network operations
    def retry_strategy = @retry_strategy ||= HTTP::RetryStrategy.new(logger:)

    # @return [Cache::Base] cache for downloaded MOD files
    def download_cache = @download_cache ||= build_cache(:download, Factorix.config.cache.download)

    # @return [Cache::Base] cache for API responses
    def api_cache = @api_cache ||= build_cache(:api, Factorix.config.cache.api)

    # @return [Cache::Base] cache for info.json metadata extracted from MOD ZIPs
    def info_json_cache = @info_json_cache ||= build_cache(:info_json, Factorix.config.cache.info_json)

    # @return [HTTP::Client] base HTTP client
    def http_client = @http_client ||= HTTP::Client.new(masked_params: %w[username token secure], logger:)

    # @return [HTTP::RetryDecorator] HTTP client for downloads (retry only;
    #   caching is handled by Downloader)
    def download_http_client = @download_http_client ||= HTTP::RetryDecorator.new(client: http_client, retry_strategy:, logger:)

    # @return [HTTP::RetryDecorator] HTTP client for API calls (cache + retry)
    def api_http_client
      @api_http_client ||= begin
        cached = HTTP::CacheDecorator.new(client: http_client, cache: api_cache, logger:)
        HTTP::RetryDecorator.new(client: cached, retry_strategy:, logger:)
      end
    end

    # @return [HTTP::RetryDecorator] HTTP client for uploads (retry only)
    def upload_http_client = @upload_http_client ||= HTTP::RetryDecorator.new(client: http_client, retry_strategy:, logger:)

    # @return [Transfer::Downloader] file downloader
    def downloader = @downloader ||= Transfer::Downloader.new(logger:, cache: download_cache, client: download_http_client)

    # @return [Transfer::Uploader] file uploader
    def uploader = @uploader ||= Transfer::Uploader.new(logger:, client: upload_http_client)

    # @return [ServiceCredential] username/token credential
    def service_credential = @service_credential ||= ServiceCredential.load

    # @return [APICredential] API key credential for MOD management
    def api_credential = @api_credential ||= APICredential.load

    # @return [API::MODPortalAPI] MOD Portal read API client
    def mod_portal_api = @mod_portal_api ||= API::MODPortalAPI.new(logger:, cache: api_cache, client: api_http_client)

    # @return [API::MODDownloadAPI] MOD download API client
    def mod_download_api = @mod_download_api ||= API::MODDownloadAPI.new(logger:)

    # @return [API::GameDownloadAPI] game download API client
    def game_download_api = @game_download_api ||= API::GameDownloadAPI.new(logger:, client: api_http_client)

    # @return [API::MODManagementAPI] MOD management API client wired to
    #   invalidate portal caches on change
    def mod_management_api
      @mod_management_api ||= API::MODManagementAPI.new(uploader:, logger:, client: http_client).tap do |api|
        api.on_mod_changed = mod_portal_api.method(:invalidate_mod_cache)
      end
    end

    # @return [Portal] high-level portal facade
    def portal = @portal ||= Portal.new(mod_portal_api:, mod_download_api:, mod_management_api:, logger:)

    private def build_cache(cache_type, config)
      backend_class = CACHE_BACKENDS.fetch(config.backend).call
      backend_config = config.public_send(config.backend).to_h
      backend_class.new(cache_type:, ttl: config.ttl, logger:, **backend_config)
    end
  end
end
