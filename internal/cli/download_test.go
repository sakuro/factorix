package cli

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDownloadRejectsOldVersion(t *testing.T) {
	newSandbox(t)
	_, err := runCLI(t, "download", "1.1.110")
	require.Error(t, err)
	assert.Equal(t, "Version 1.1.110 is not supported. Minimum version is 2.0.0", err.Error())
}

func TestDownloadRejectsInvalidVersion(t *testing.T) {
	newSandbox(t)
	_, err := runCLI(t, "download", "banana")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Invalid version format: ")
}

func TestDownloadRejectsMissingDirectory(t *testing.T) {
	s := newSandbox(t)
	missing := filepath.Join(s.root, "no-such-dir")
	_, err := runCLI(t, "download", "2.0.0", "-d", missing, "-o", "game.tar.xz")
	require.Error(t, err)
	assert.Equal(t, "Download directory does not exist: "+missing, err.Error())
}

func TestDownloadRejectsInvalidBuildAndPlatform(t *testing.T) {
	newSandbox(t)
	_, err := runCLI(t, "download", "2.0.0", "-b", "bogus", "-o", "game.tar.xz")
	require.Error(t, err)
	assert.Contains(t, err.Error(), `invalid build: "bogus"`)

	_, err = runCLI(t, "download", "2.0.0", "-p", "bogus", "-o", "game.tar.xz")
	require.Error(t, err)
	assert.Contains(t, err.Error(), `invalid platform: "bogus"`)
}

// Without player-data.json or FACTORIO_USERNAME/FACTORIO_TOKEN the download
// must fail at credential resolution, before any request.
func TestDownloadRequiresCredentials(t *testing.T) {
	newSandbox(t)
	t.Setenv("FACTORIO_USERNAME", "")
	t.Setenv("FACTORIO_TOKEN", "")
	_, err := runCLI(t, "download", "2.0.0", "-o", "game.tar.xz")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "credential")
}
