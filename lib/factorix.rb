# frozen_string_literal: true

require "dry/auto_inject"
require "dry/configurable"
require "zeitwerk"
require_relative "factorix/errors"
require_relative "factorix/version"

# Factorix provides a CLI for Factorio MOD management, settings synchronization,
# and MOD Portal integration.
#
# @example Configure Factorix
#   Factorix.configure do |config|
#     config.log_level = :debug
#     config.http.connect_timeout = 10
#   end
module Factorix
  extend Dry::Configurable

  # Log level (:debug, :info, :warn, :error, :fatal)
  setting :log_level, default: :info

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
  # Each cache type can have its own backend with hierarchical configuration.
  # Common settings (backend, ttl) apply to all backends.
  # Backend-specific settings are nested under the backend name.
  setting :cache do
    # Download cache settings (for MOD files)
    setting :download do
      setting :backend, default: :file_system
      setting :ttl, default: nil # nil for unlimited (MOD files are immutable)
      setting :file_system do
        setting :root, constructor: ->(value) { value ? Pathname(value) : nil }
        setting :max_file_size, default: nil # nil for unlimited
        setting :compression_threshold, default: nil # nil for no compression (binary files)
      end
    end

    # API cache settings (for API responses)
    setting :api do
      setting :backend, default: :file_system
      setting :ttl, default: 3600 # 1 hour (API responses may change)
      setting :file_system do
        setting :root, constructor: ->(value) { value ? Pathname(value) : nil }
        setting :max_file_size, default: 10 * 1024 * 1024 # 10MiB (JSON responses)
        setting :compression_threshold, default: 0 # always compress (JSON is highly compressible)
      end
    end

    # info.json cache settings (for MOD metadata from ZIP files)
    setting :info_json do
      setting :backend, default: :file_system
      setting :ttl, default: nil # nil for unlimited (info.json is immutable within a MOD ZIP)
      setting :file_system do
        setting :root, constructor: ->(value) { value ? Pathname(value) : nil }
        setting :max_file_size, default: nil # nil for unlimited (info.json is small)
        setting :compression_threshold, default: 0 # always compress (JSON is highly compressible)
      end
    end
  end

  # Load configuration from file
  #
  # @param path [Pathname, nil] configuration file path
  # @return [void]
  # @raise [ConfigurationError] if explicitly specified path does not exist
  def self.load_config(path=nil)
    if path
      # Explicitly specified path must exist
      raise ConfigurationError, "Configuration file not found: #{path}" unless path.exist?

      config_path = path
    else
      # Default path is optional
      config_path = Container.resolve(:runtime).factorix_config_path
      return unless config_path.exist?
    end

    instance_eval(config_path.read, config_path.to_s)
  end

  loader = Zeitwerk::Loader.for_gem
  loader.ignore("#{__dir__}/factorix/version.rb")
  loader.ignore("#{__dir__}/factorix/errors.rb")
  loader.inflector.inflect(
    "api" => "API",
    "api_credential" => "APICredential",
    "cli" => "CLI",
    "http" => "HTTP",
    "info_json" => "InfoJSON",
    "installed_mod" => "InstalledMOD",
    "mac_os" => "MacOS",
    "mod" => "MOD",
    "mod_download_api" => "MODDownloadAPI",
    "mod_info" => "MODInfo",
    "mod_management_api" => "MODManagementAPI",
    "mod_list" => "MODList",
    "mod_portal_api" => "MODPortalAPI",
    "mod_settings" => "MODSettings",
    "mod_state" => "MODState",
    "mod_version" => "MODVersion",
    "mod_version_requirement" => "MODVersionRequirement",
    "wsl" => "WSL"
  )
  loader.setup

  Import = Dry::AutoInject(Container)
  public_constant :Import

  # Initialize cache directory defaults after Container is loaded
  runtime = Container.resolve(:runtime)
  config.cache.download.file_system.root = runtime.factorix_cache_dir / "download"
  config.cache.api.file_system.root = runtime.factorix_cache_dir / "api"
  config.cache.info_json.file_system.root = runtime.factorix_cache_dir / "info_json"

  # @deprecated Use {Container} for DI and {Factorix} for configuration. Will be removed in v1.0.
  class Application
    # @!method [](key)
    #   @deprecated Use {Container.[]} instead
    def self.[](key)
      warn "[factorix] Factorix::Application is deprecated, use Factorix::Container for DI"
      Container[key]
    end

    # @!method resolve(key)
    #   @deprecated Use {Container.resolve} instead
    def self.resolve(key)
      warn "[factorix] Factorix::Application is deprecated, use Factorix::Container for DI"
      Container.resolve(key)
    end

    # @!method register(...)
    #   @deprecated Use {Container.register} instead
    def self.register(...)
      warn "[factorix] Factorix::Application is deprecated, use Factorix::Container for DI"
      Container.register(...)
    end

    # @!method config
    #   @deprecated Use {Factorix.config} instead
    def self.config
      warn "[factorix] Factorix::Application is deprecated, use Factorix.config for configuration"
      Factorix.config
    end

    # @!method configure(&block)
    #   @deprecated Use {Factorix.configure} instead
    def self.configure(&)
      warn "[factorix] Factorix::Application is deprecated, use Factorix.configure for configuration"
      Factorix.configure(&)
    end
  end
end
