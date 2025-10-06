# frozen_string_literal: true

require "dry/cli"

module Factorix
  # Command-line interface for Factorix
  class CLI
    extend Dry::CLI::Registry

    register "info", Factorix::CLI::Commands::Info
    register "launch", Factorix::CLI::Commands::Launch
    register "mod disable", Factorix::CLI::Commands::Mod::Disable
    register "mod enable", Factorix::CLI::Commands::Mod::Enable
    register "mod list", Factorix::CLI::Commands::Mod::List
    register "mod new", Factorix::CLI::Commands::Mod::New
    register "mod settings dump", Factorix::CLI::Commands::Mod::Settings::Dump
    register "mod download", Factorix::CLI::Commands::Mod::Download
  end
end
