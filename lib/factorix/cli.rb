# frozen_string_literal: true

require "dry/cli"

require_relative "cli/commands/disable"
require_relative "cli/commands/enable"
require_relative "cli/commands/info"
require_relative "cli/commands/launch"

module Factorix
  # Command-line interface for Factorix
  class CLI
    extend Dry::CLI::Registry

    register "enable", Factorix::CLI::Commands::Enable
    register "disable", Factorix::CLI::Commands::Disable
    register "info", Factorix::CLI::Commands::Info
    register "launch", Factorix::CLI::Commands::Launch
  end
end
