package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func writeConfig(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "config.toml")
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))
	return path
}

func TestDefault(t *testing.T) {
	cfg := Default()
	assert.Equal(t, "info", cfg.LogLevel)
	assert.Equal(t, "localhost", cfg.RCON.Host)
	assert.Equal(t, 27015, cfg.RCON.Port)
	assert.Equal(t, 5, cfg.HTTP.ConnectTimeout)

	assert.Nil(t, cfg.Cache.Download.TTL)
	require.NotNil(t, cfg.Cache.API.TTL)
	assert.Equal(t, int64(3600), *cfg.Cache.API.TTL)
	require.NotNil(t, cfg.Cache.API.FileSystem.MaxFileSize)
	assert.Equal(t, int64(10*1024*1024), *cfg.Cache.API.FileSystem.MaxFileSize)
	assert.Nil(t, cfg.Cache.InfoJSON.FileSystem.MaxFileSize)
	require.NotNil(t, cfg.Cache.InfoJSON.FileSystem.CompressionThreshold)

	require.NoError(t, cfg.validate())
}

func TestLoadFile(t *testing.T) {
	path := writeConfig(t, `
log_level = "debug"

[runtime]
executable_path = "/opt/factorio/bin/x64/factorio"

[rcon]
port = 34197

[cache.api]
ttl = 60
`)
	cfg, err := LoadFile(path)
	require.NoError(t, err)

	assert.Equal(t, "debug", cfg.LogLevel)
	assert.Equal(t, "/opt/factorio/bin/x64/factorio", cfg.Runtime.ExecutablePath)
	assert.Empty(t, cfg.Runtime.UserDir)

	// Unspecified values keep their defaults.
	assert.Equal(t, "localhost", cfg.RCON.Host)
	assert.Equal(t, 34197, cfg.RCON.Port)
	require.NotNil(t, cfg.Cache.API.TTL)
	assert.Equal(t, int64(60), *cfg.Cache.API.TTL)
	require.NotNil(t, cfg.Cache.API.FileSystem.MaxFileSize)
}

func TestLoadFileToleratesRubyLegacyKeys(t *testing.T) {
	// Redis/S3 sections from Ruby-era configuration files load but are ignored.
	path := writeConfig(t, `
[cache.download.redis]
url = "redis://localhost"
lock_timeout = 30

[cache.download.s3]
bucket = "my-bucket"
region = "us-east-1"
`)
	_, err := LoadFile(path)
	require.NoError(t, err)
}

func TestLoadFileUnknownKey(t *testing.T) {
	path := writeConfig(t, `unknown_key = 1`)
	_, err := LoadFile(path)
	require.ErrorIs(t, err, ErrInvalidConfig)
	assert.Contains(t, err.Error(), "unknown_key")
}

func TestLoadFileInvalidTOML(t *testing.T) {
	path := writeConfig(t, `log_level = `)
	_, err := LoadFile(path)
	require.ErrorIs(t, err, ErrInvalidConfig)
}

func TestLoadFileInvalidLogLevel(t *testing.T) {
	path := writeConfig(t, `log_level = "verbose"`)
	_, err := LoadFile(path)
	require.ErrorIs(t, err, ErrInvalidConfig)
	assert.Contains(t, err.Error(), "log_level")
}

func TestLoadFileUnsupportedBackend(t *testing.T) {
	path := writeConfig(t, `
[cache.api]
backend = "redis"
`)
	_, err := LoadFile(path)
	require.ErrorIs(t, err, ErrInvalidConfig)
	assert.Contains(t, err.Error(), "backend")
}

func TestLoadFileMissing(t *testing.T) {
	_, err := LoadFile(filepath.Join(t.TempDir(), "missing.toml"))
	require.ErrorIs(t, err, os.ErrNotExist)
}
