# frozen_string_literal: true

require "dry/auto_inject"
require "zeitwerk"
require_relative "factorix/errors"
require_relative "factorix/version"

# Factorix provides a CLI for Factorio MOD management, settings synchronization,
# and MOD Portal integration.
module Factorix
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
end
