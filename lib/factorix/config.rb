# frozen_string_literal: true

require "pathname"
require "perfect_toml"

module Factorix
  # Application configuration
  #
  # Immutable value object built from defaults merged with a TOML
  # configuration file (see Factorix.load_config).
  Config = Data.define(:log_level, :runtime, :rcon, :http, :cache)

  # Construction, defaults, and TOML loading for the configuration
  class Config
    # Runtime path overrides (nil means platform auto-detection)
    Runtime = Data.define(:executable_path, :user_dir, :data_dir)

    # RCON connection settings
    RCon = Data.define(:host, :port, :password)

    # HTTP timeout settings
    HTTP = Data.define(:connect_timeout, :read_timeout, :write_timeout)

    # Cache settings per cache type
    Cache = Data.define(:download, :api, :info_json)

    # Settings for a single cache type
    CacheType = Data.define(:backend, :ttl, :file_system, :redis, :s3)

    # Filesystem cache backend settings
    FileSystemBackend = Data.define(:max_file_size, :compression_threshold)

    # Redis cache backend settings
    RedisBackend = Data.define(:url, :lock_timeout)

    # S3 cache backend settings
    S3Backend = Data.define(:bucket, :region, :lock_timeout)

    # Default values; also serves as the catalog of valid keys
    DEFAULTS = {
      log_level: :info,
      runtime: {executable_path: nil, user_dir: nil, data_dir: nil},
      rcon: {host: "localhost", port: 27015, password: nil},
      http: {connect_timeout: 5, read_timeout: 30, write_timeout: 30},
      cache: {
        download: {
          backend: :file_system,
          ttl: nil, # unlimited (MOD files are immutable)
          file_system: {max_file_size: nil, compression_threshold: nil},
          redis: {url: nil, lock_timeout: 30},
          s3: {bucket: nil, region: nil, lock_timeout: 30}
        },
        api: {
          backend: :file_system,
          ttl: 3600, # API responses may change
          file_system: {max_file_size: 10 * 1024 * 1024, compression_threshold: 0},
          redis: {url: nil, lock_timeout: 30},
          s3: {bucket: nil, region: nil, lock_timeout: 30}
        },
        info_json: {
          backend: :file_system,
          ttl: nil, # info.json is immutable within a MOD ZIP
          file_system: {max_file_size: nil, compression_threshold: 0},
          redis: {url: nil, lock_timeout: 30},
          s3: {bucket: nil, region: nil, lock_timeout: 30}
        }
      }
    }.freeze
    private_constant :DEFAULTS

    # Build the default configuration
    #
    # @return [Config]
    def self.default = from_h({})

    # Load configuration from a TOML file
    #
    # @param path [Pathname] path to the TOML file
    # @return [Config]
    # @raise [ConfigurationError] if the file contains invalid keys or TOML
    def self.load_file(path)
      from_h(symbolize(PerfectTOML.load_file(path.to_s)))
    rescue PerfectTOML::ParseError => e
      raise ConfigurationError, "Invalid TOML in #{path}: #{e.message}"
    end

    # Build configuration from a nested hash merged over the defaults
    #
    # @param hash [Hash{Symbol => untyped}] configuration values
    # @return [Config]
    # @raise [ConfigurationError] if the hash contains unknown keys
    def self.from_h(hash)
      validate!(hash, DEFAULTS, [])
      build(deep_merge(DEFAULTS, hash))
    end

    private_class_method def self.validate!(hash, defaults, trail)
      hash.each do |key, value|
        path = (trail + [key]).join(".")
        raise ConfigurationError, "Unknown configuration key: #{path}" unless defaults.key?(key)
        next unless defaults[key].is_a?(Hash)
        raise ConfigurationError, "Configuration key #{path} must be a table" unless value.is_a?(Hash)

        validate!(value, defaults[key], trail + [key])
      end
    end

    private_class_method def self.deep_merge(base, overrides)
      base.merge(overrides) do |_key, base_value, override_value|
        base_value.is_a?(Hash) ? deep_merge(base_value, override_value) : override_value
      end
    end

    private_class_method def self.symbolize(value)
      case value
      when Hash
        value.to_h {|key, val| [key.to_sym, symbolize(val)] }
      else
        value
      end
    end

    private_class_method def self.build(values)
      Config[
        log_level: values[:log_level].to_sym,
        runtime: build_runtime(values[:runtime]),
        rcon: RCon[**values[:rcon]],
        http: HTTP[**values[:http]],
        cache: Cache[
          download: build_cache_type(values[:cache][:download]),
          api: build_cache_type(values[:cache][:api]),
          info_json: build_cache_type(values[:cache][:info_json])
        ]
      ]
    end

    private_class_method def self.build_runtime(values)
      Runtime[**values.transform_values {|value| value && Pathname(value) }]
    end

    private_class_method def self.build_cache_type(values)
      CacheType[
        backend: values[:backend].to_sym,
        ttl: values[:ttl],
        file_system: FileSystemBackend[**values[:file_system]],
        redis: RedisBackend[**values[:redis]],
        s3: S3Backend[**values[:s3]]
      ]
    end
  end
end
