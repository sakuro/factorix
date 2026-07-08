// Package config loads the Factorix configuration from config.toml.
// The file format is shared with the Ruby implementation, so existing
// configuration files carry over unchanged.
package config

import (
	"errors"
	"fmt"
	"os"
	"slices"

	"github.com/BurntSushi/toml"
)

var ErrInvalidConfig = errors.New("invalid configuration")

// Config is the application configuration.
type Config struct {
	LogLevel string  `toml:"log_level"`
	Runtime  Runtime `toml:"runtime"`
	RCON     RCON    `toml:"rcon"`
	HTTP     HTTP    `toml:"http"`
	Cache    Cache   `toml:"cache"`
}

// Runtime holds path overrides; an empty value means platform auto-detection.
type Runtime struct {
	ExecutablePath string `toml:"executable_path"`
	UserDir        string `toml:"user_dir"`
	DataDir        string `toml:"data_dir"`
}

// RCON holds RCON connection settings.
type RCON struct {
	Host     string `toml:"host"`
	Port     int    `toml:"port"`
	Password string `toml:"password"`
}

// HTTP holds HTTP timeout settings in seconds.
type HTTP struct {
	ConnectTimeout int `toml:"connect_timeout"`
	ReadTimeout    int `toml:"read_timeout"`
	WriteTimeout   int `toml:"write_timeout"`
}

// Cache holds the per-cache-type settings.
type Cache struct {
	Download CacheType `toml:"download"`
	API      CacheType `toml:"api"`
	InfoJSON CacheType `toml:"info_json"`
}

// CacheType configures one cache instance.
type CacheType struct {
	Backend    string            `toml:"backend"`
	TTL        *int64            `toml:"ttl"` // seconds; nil = unlimited
	FileSystem FileSystemBackend `toml:"file_system"`
	// Redis and S3 are accepted so Ruby-era configuration files still load,
	// but the backends are out of scope for the Go version and the values
	// are ignored.
	Redis RedisBackend `toml:"redis"`
	S3    S3Backend    `toml:"s3"`
}

// FileSystemBackend configures the filesystem cache backend.
type FileSystemBackend struct {
	MaxFileSize          *int64 `toml:"max_file_size"`         // bytes; nil = unlimited
	CompressionThreshold *int64 `toml:"compression_threshold"` // bytes; nil = never compress
}

// RedisBackend is accepted for Ruby-file compatibility only.
type RedisBackend struct {
	URL         string `toml:"url"`
	LockTimeout int64  `toml:"lock_timeout"`
}

// S3Backend is accepted for Ruby-file compatibility only.
type S3Backend struct {
	Bucket      string `toml:"bucket"`
	Region      string `toml:"region"`
	LockTimeout int64  `toml:"lock_timeout"`
}

var validLogLevels = []string{"debug", "info", "warn", "error", "fatal"}

func int64Ptr(v int64) *int64 {
	return &v
}

// Default returns the default configuration, matching the Ruby DEFAULTS.
func Default() Config {
	return Config{
		LogLevel: "info",
		RCON:     RCON{Host: "localhost", Port: 27015},
		HTTP:     HTTP{ConnectTimeout: 5, ReadTimeout: 30, WriteTimeout: 30},
		Cache: Cache{
			// MOD files are immutable: no TTL, no size limit.
			Download: CacheType{Backend: "file_system"},
			// API responses may change.
			API: CacheType{
				Backend: "file_system",
				TTL:     int64Ptr(3600),
				FileSystem: FileSystemBackend{
					MaxFileSize:          int64Ptr(10 * 1024 * 1024),
					CompressionThreshold: int64Ptr(0),
				},
			},
			// info.json is immutable within a MOD ZIP.
			InfoJSON: CacheType{
				Backend:    "file_system",
				FileSystem: FileSystemBackend{CompressionThreshold: int64Ptr(0)},
			},
		},
	}
}

// LoadFile reads a config.toml, applying its values over the defaults.
func LoadFile(path string) (Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Config{}, err
	}

	cfg := Default()
	meta, err := toml.Decode(string(data), &cfg)
	if err != nil {
		return Config{}, fmt.Errorf("%w: invalid TOML in %s: %s", ErrInvalidConfig, path, err)
	}
	if undecoded := meta.Undecoded(); len(undecoded) > 0 {
		return Config{}, fmt.Errorf("%w: unknown configuration key: %s", ErrInvalidConfig, undecoded[0])
	}
	if err := cfg.validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (c Config) validate() error {
	if !slices.Contains(validLogLevels, c.LogLevel) {
		return fmt.Errorf("%w: invalid log_level: %q", ErrInvalidConfig, c.LogLevel)
	}
	for name, ct := range map[string]CacheType{
		"download":  c.Cache.Download,
		"api":       c.Cache.API,
		"info_json": c.Cache.InfoJSON,
	} {
		if ct.Backend != "file_system" {
			return fmt.Errorf("%w: cache.%s.backend %q is not supported (only file_system)", ErrInvalidConfig, name, ct.Backend)
		}
	}
	return nil
}
