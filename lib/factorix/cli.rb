# frozen_string_literal: true

require "dry/cli"

module Factorix
  # Command-line interface for Factorix
  #
  # This class serves as the registry for all CLI commands using dry-cli.
  # Commands are registered with their names and mapped to command classes.
  #
  # @example Running the CLI
  #   Dry::CLI.new(Factorix::CLI).call
  class CLI
    extend Dry::CLI::Registry

    register "version", Commands::Version
    register "launch", Commands::Launch
    register "path", Commands::Path
    register "mod download", Commands::MOD::Download
    register "mod settings dump", Commands::MOD::Settings::Dump
    register "mod settings restore", Commands::MOD::Settings::Restore
  end
end
