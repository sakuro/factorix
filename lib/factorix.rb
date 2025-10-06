# frozen_string_literal: true

require_relative "factorix/errors"
require_relative "factorix/version"

require "zeitwerk"

# Factorix is a Factorio MOD management and development tool.
module Factorix
  loader = Zeitwerk::Loader.for_gem
  loader.inflector.inflect(
    "api" => "API",
    "cli" => "CLI",
    "http_client" => "HTTPClient",
    "mac_os" => "MacOS",
    "wsl" => "WSL"
  )
  loader.ignore("#{__dir__}/factorix/errors.rb")
  loader.ignore("#{__dir__}/factorix/version.rb")
  loader.setup
  loader.eager_load
end
