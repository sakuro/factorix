# frozen_string_literal: true

require "zeitwerk"
require_relative "factorix/version"

# Factorix provides [description of your gem].
#
# This module serves as the namespace for the gem's functionality.
module Factorix
  class Error < StandardError; end

  loader = Zeitwerk::Loader.for_gem
  loader.ignore("#{__dir__}/factorix/version.rb")
  # loader.inflector.inflect(
  #   "html" => "HTML",
  #   "ssl" => "SSL"
  # )
  loader.setup
end
