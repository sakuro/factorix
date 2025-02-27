# frozen_string_literal: true

require "dry/cli"

require_relative "cli/commands/info"
require_relative "cli/commands/launch"
require_relative "cli/commands/mod/disable"
require_relative "cli/commands/mod/enable"

module Factorix
  # Command-line interface for Factorix
  class CLI
    extend Dry::CLI::Registry

    register "info", Factorix::CLI::Commands::Info
    register "launch", Factorix::CLI::Commands::Launch
    register "mod disable", Factorix::CLI::Commands::Mod::Disable
    register "mod enable", Factorix::CLI::Commands::Mod::Enable
  end
end
