package cli

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/cache"
)

func TestFormatSize(t *testing.T) {
	assert.Equal(t, "0 B", formatSize(0))
	assert.Equal(t, "1023 B", formatSize(1023))
	assert.Equal(t, "1.0 KiB", formatSize(1024))
	assert.Equal(t, "1.5 KiB", formatSize(1536))
	assert.Equal(t, "1.0 MiB", formatSize(1024*1024))
	assert.Equal(t, "unlimited", formatSizeLimit(nil))
}

func TestFormatDuration(t *testing.T) {
	assert.Equal(t, "59s", formatDuration(59))
	assert.Equal(t, "1m", formatDuration(60))
	assert.Equal(t, "59m", formatDuration(3599))
	assert.Equal(t, "1h 0m", formatDuration(3600))
	assert.Equal(t, "1h 1m", formatDuration(3661))
	assert.Equal(t, "1d 0h", formatDuration(86400))
	assert.Equal(t, "7d 3h", formatDuration(7*86400+3*3600))
}

func TestParseAge(t *testing.T) {
	for input, want := range map[string]time.Duration{
		"30s": 30 * time.Second,
		"5m":  5 * time.Minute,
		"2h":  2 * time.Hour,
		"7d":  7 * 24 * time.Hour,
	} {
		got, err := parseAge(input)
		require.NoError(t, err, input)
		assert.Equal(t, want, got, input)
	}

	_, err := parseAge("7w")
	require.Error(t, err)
	assert.Equal(t, "Invalid age format: 7w. Use format like 30s, 5m, 2h, 7d", err.Error())
}

func TestCacheStatEmpty(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "cache", "stat")
	require.NoError(t, err)

	// Canonical cache order.
	download := strings.Index(out, "download:\n")
	api := strings.Index(out, "api:\n")
	infoJSON := strings.Index(out, "info_json:\n")
	require.GreaterOrEqual(t, download, 0)
	assert.Greater(t, api, download)
	assert.Greater(t, infoJSON, api)

	assert.Contains(t, out, "download:\n"+
		"  TTL:            unlimited\n"+
		"  Entries:        0 / 0 (0.0% valid)\n"+
		"  Size:           0 B (avg 0 B)\n"+
		"  Age:            -\n"+
		"  Backend:\n"+
		"    Type:                file_system\n")
	// The api cache has a TTL by default.
	assert.Contains(t, out, "api:\n  TTL:            1h 0m\n")
	assert.Contains(t, out, "    Stale locks:         0\n")
}

// statDirectories runs cache stat --json and returns each cache's backend
// directory.
func statDirectories(t *testing.T) map[string]string {
	t.Helper()
	out, err := runCLI(t, "cache", "stat", "--json")
	require.NoError(t, err)

	var stats map[string]struct {
		Backend struct {
			Directory string `json:"directory"`
		} `json:"backend_info"`
	}
	require.NoError(t, json.Unmarshal([]byte(out), &stats))
	dirs := map[string]string{}
	for name, s := range stats {
		dirs[name] = s.Backend.Directory
	}
	return dirs
}

func TestCacheStatJSONKeyOrder(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "cache", "stat", "--json")
	require.NoError(t, err)

	download := strings.Index(out, `"download":`)
	api := strings.Index(out, `"api":`)
	infoJSON := strings.Index(out, `"info_json":`)
	require.GreaterOrEqual(t, download, 0)
	assert.Greater(t, api, download)
	assert.Greater(t, infoJSON, api)
	assert.Contains(t, out, `"ttl": null`)
	assert.Contains(t, out, `"ttl": 3600`)
}

func TestCacheEvictAll(t *testing.T) {
	s := newSandbox(t)
	dirs := statDirectories(t)
	require.Contains(t, dirs, "download")

	// Seed one entry in the download cache through the same backend.
	fs, err := cache.NewFileSystem(dirs["download"], cache.FileSystemOptions{})
	require.NoError(t, err)
	srcPath := filepath.Join(s.root, "payload.bin")
	require.NoError(t, os.WriteFile(srcPath, []byte("0123456789"), 0o644))
	stored, err := fs.Store(context.Background(), "some-key", srcPath)
	require.NoError(t, err)
	require.True(t, stored)

	out, err := runCLI(t, "cache", "evict", "--all")
	require.NoError(t, err)
	assert.Contains(t, out, "ℹ download :   1 entries removed (10 B)\n")
	assert.Contains(t, out, "ℹ api      :   0 entries removed (0 B)\n")
	assert.Contains(t, out, "ℹ info_json:   0 entries removed (0 B)\n")

	entries, err := fs.Entries(context.Background())
	require.NoError(t, err)
	assert.Empty(t, entries)
}

func TestCacheEvictNamedCacheOnly(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "cache", "evict", "api", "--expired")
	require.NoError(t, err)
	assert.Contains(t, out, "api:   0 entries removed (0 B)\n")
	assert.NotContains(t, out, "download")
}

func TestCacheEvictOptionValidation(t *testing.T) {
	newSandbox(t)

	_, err := runCLI(t, "cache", "evict")
	require.Error(t, err)
	assert.Equal(t, "One of --all, --expired, or --older-than must be specified", err.Error())

	_, err = runCLI(t, "cache", "evict", "--all", "--expired")
	require.Error(t, err)
	assert.Equal(t, "Only one of --all, --expired, or --older-than can be specified", err.Error())

	_, err = runCLI(t, "cache", "evict", "--older-than", "banana")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Invalid age format: banana")

	_, err = runCLI(t, "cache", "evict", "bogus", "--all")
	require.Error(t, err)
	assert.Equal(t, "Unknown cache: bogus. Valid caches: download, api, info_json", err.Error())
}

func TestCacheEvictOlderThan(t *testing.T) {
	s := newSandbox(t)
	dirs := statDirectories(t)
	fs, err := cache.NewFileSystem(dirs["download"], cache.FileSystemOptions{})
	require.NoError(t, err)
	srcPath := filepath.Join(s.root, "payload.bin")
	require.NoError(t, os.WriteFile(srcPath, []byte("x"), 0o644))
	_, err = fs.Store(context.Background(), "fresh-key", srcPath)
	require.NoError(t, err)

	// A fresh entry is not older than 1 hour.
	out, err := runCLI(t, "cache", "evict", "download", "--older-than", "1h")
	require.NoError(t, err)
	assert.Contains(t, out, "download:   0 entries removed (0 B)\n")

	entries, err := fs.Entries(context.Background())
	require.NoError(t, err)
	assert.Len(t, entries, 1)
}
