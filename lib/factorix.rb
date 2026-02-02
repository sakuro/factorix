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
        setting :max_file_size, default: nil # nil for unlimited
        setting :compression_threshold, default: nil # nil for no compression (binary files)
      end
      setting :redis do
        setting :url, default: nil # nil falls back to REDIS_URL env, then localhost:6379
        setting :lock_timeout, default: 30
      end
      setting :s3 do
        setting :bucket, default: nil # required when using S3 backend
        setting :region, default: nil # nil falls back to AWS_REGION env or SDK default
        setting :lock_timeout, default: 30
      end
    end

    # API cache settings (for API responses)
    setting :api do
      setting :backend, default: :file_system
      setting :ttl, default: 3600 # 1 hour (API responses may change)
      setting :file_system do
        setting :max_file_size, default: 10 * 1024 * 1024 # 10MiB (JSON responses)
        setting :compression_threshold, default: 0 # always compress (JSON is highly compressible)
      end
      setting :redis do
        setting :url, default: nil # nil falls back to REDIS_URL env, then localhost:6379
        setting :lock_timeout, default: 30
      end
      setting :s3 do
        setting :bucket, default: nil # required when using S3 backend
        setting :region, default: nil # nil falls back to AWS_REGION env or SDK default
        setting :lock_timeout, default: 30
      end
    end

    # info.json cache settings (for MOD metadata from ZIP files)
    setting :info_json do
      setting :backend, default: :file_system
      setting :ttl, default: nil # nil for unlimited (info.json is immutable within a MOD ZIP)
      setting :file_system do
        setting :max_file_size, default: nil # nil for unlimited (info.json is small)
        setting :compression_threshold, default: 0 # always compress (JSON is highly compressible)
      end
      setting :redis do
        setting :url, default: nil # nil falls back to REDIS_URL env, then localhost:6379
        setting :lock_timeout, default: 30
      end
      setting :s3 do
        setting :bucket, default: nil # required when using S3 backend
        setting :region, default: nil # nil falls back to AWS_REGION env or SDK default
        setting :lock_timeout, default: 30
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
    "game_download_api" => "GameDownloadAPI",
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
end
