# frozen_string_literal: true

require "dry-configurable"
require "dry-container"

module Factorix
  # Application container and configuration
  #
  # Provides dependency injection container and configuration management
  # using dry-container and dry-configurable.
  #
  # @example Configure the application
  #   Factorix::Application.configure do |config|
  #     config.log_level = :debug
  #     config.http.connect_timeout = 10
  #   end
  #
  # @example Resolve dependencies
  #   runtime = Factorix::Application[:runtime]
  class Application
    extend Dry::Container::Mixin
    extend Dry::Configurable

    # Register runtime detector
    register(:runtime) do
      Factorix::Runtime.detect
    end

    # Register retry strategy for network operations
    register(:retry_strategy) do
      Factorix::Transfer::RetryStrategy.new
    end

    # Cache directory path
    setting :cache_dir, constructor: ->(value) { Pathname(value) }

    # Log level (:debug, :info, :warn, :error, :fatal)
    setting :log_level, default: :info

    # HTTP timeout settings
    setting :http do
      setting :connect_timeout, default: 5
      setting :read_timeout, default: 30
      setting :write_timeout, default: 30
    end

    # Load configuration from file
    #
    # @param path [Pathname, String, nil] configuration file path
    # @return [void]
    # @raise [Errno::ENOENT] if explicitly specified path does not exist
    def self.load_config(path=nil)
      if path
        # Explicitly specified path must exist
        config_path = Pathname(path)
        raise Errno::ENOENT, config_path.to_s unless config_path.exist?
      else
        # Default path is optional
        config_path = resolve(:runtime).factorix_config_path
        return unless config_path.exist?
      end

      instance_eval(config_path.read, config_path.to_s)
    end

    # Set default values that depend on runtime
    config.cache_dir = resolve(:runtime).factorix_cache_dir
  end
end
