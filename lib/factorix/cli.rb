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
    register "man", Commands::Man
    register "launch", Commands::Launch
    register "path", Commands::Path
    register "mod check", Commands::MOD::Check
    register "mod list", Commands::MOD::List
    register "mod show", Commands::MOD::Show
    register "mod enable", Commands::MOD::Enable
    register "mod disable", Commands::MOD::Disable
    register "mod install", Commands::MOD::Install
    register "mod uninstall", Commands::MOD::Uninstall
    register "mod update", Commands::MOD::Update
    register "mod download", Commands::MOD::Download
    register "mod upload", Commands::MOD::Upload
    register "mod edit", Commands::MOD::Edit
    register "mod search", Commands::MOD::Search
    register "mod sync", Commands::MOD::Sync
    register "mod image list", Commands::MOD::Image::List
    register "mod image add", Commands::MOD::Image::Add
    register "mod image edit", Commands::MOD::Image::Edit
    register "mod settings dump", Commands::MOD::Settings::Dump
    register "mod settings restore", Commands::MOD::Settings::Restore
    register "cache stat", Commands::Cache::Stat
    register "cache evict", Commands::Cache::Evict
  end
end
