# frozen_string_literal: true

require "zeitwerk"
require_relative "factorix/errors"
require_relative "factorix/version"

# Factorix provides a CLI for Factorio MOD management, settings synchronization,
# and MOD Portal integration.
#
# Configuration is read from a TOML file (see Factorix.load_config):
#
#   log_level = "debug"
#
#   [http]
#   connect_timeout = 10
module Factorix
  # Get the application composition root
  #
  # @return [Application] the shared application instance
  def self.app = @app ||= Application.new

  # Replace the application composition root
  #
  # @param app [Application] the application instance to use
  def self.app=(app)
    @app = app
  end

  # Reset the application composition root
  #
  # @return [void]
  def self.reset_app
    @app = nil
  end

  # Get the current configuration
  #
  # @return [Config] the current configuration (defaults until load_config is called)
  def self.config = @config ||= Config.default

  # Replace the current configuration
  #
  # @param config [Config] the configuration to use
  # @return [void]
  def self.config=(config)
    @config = config
  end

  # Reset the configuration to defaults
  #
  # @return [void]
  def self.reset_config
    @config = nil
  end

  # Load configuration from a TOML file
  #
  # With an explicit path the file must exist. Without a path the default
  # location (runtime.factorix_config_path) is used if present; a legacy
  # Ruby-DSL config found there is converted to TOML and reported instead.
  #
  # @param path [Pathname, nil] configuration file path
  # @return [void]
  # @raise [ConfigurationError] if an explicitly specified path does not exist,
  #   or a legacy Ruby-DSL configuration requires migration
  def self.load_config(path=nil)
    if path
      raise ConfigurationError, "Configuration file not found: #{path}" unless path.exist?

      raise_legacy_config(path, target: path.sub_ext(".toml")) if path.extname == ".rb"

      @config = Config.load_file(path)
    else
      default_path = Factorix.app.runtime.factorix_config_path
      legacy_path = default_path.sub_ext(".rb")

      if default_path.exist?
        @config = Config.load_file(default_path)
      elsif legacy_path.exist?
        raise_legacy_config(legacy_path, target: default_path)
      end
    end
  end

  private_class_method def self.raise_legacy_config(legacy_path, target:)
    toml = Config::LegacyConverter.convert(legacy_path)
    raise ConfigurationError, <<~MESSAGE
      Factorix now uses TOML for configuration and no longer reads #{legacy_path}.
      Review the equivalent TOML below, save it to #{target}, then remove the legacy file:

      #{toml}
    MESSAGE
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
    "rcon" => "RCon",
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
end
