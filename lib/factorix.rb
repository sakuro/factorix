# frozen_string_literal: true

require "dry-auto_inject"
require "zeitwerk"
require_relative "factorix/errors"
require_relative "factorix/version"

# Factorix provides [description of your gem].
#
# This module serves as the namespace for the gem's functionality.
module Factorix
  loader = Zeitwerk::Loader.for_gem
  loader.ignore("#{__dir__}/factorix/version.rb")
  loader.ignore("#{__dir__}/factorix/errors.rb")
  loader.inflector.inflect(
    "api_credential" => "APICredential",
    "http" => "HTTP",
    "mac_os" => "MacOS",
    "mod_version" => "MODVersion",
    "wsl" => "WSL"
  )
  loader.setup

  Import = Dry::AutoInject(Application)
  public_constant :Import
end
