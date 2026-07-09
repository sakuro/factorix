package cli

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/mod"
)

func TestMODShowRejectsBuiltinMODs(t *testing.T) {
	newSandbox(t)

	_, err := runCLI(t, "mod", "show", "base")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Cannot show base MOD")

	_, err = runCLI(t, "mod", "show", "space-age")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Cannot show expansion MOD: space-age")
}

func TestMODDownloadRejectsMissingDirectory(t *testing.T) {
	newSandbox(t)

	_, err := runCLI(t, "mod", "download", "-d", "/nonexistent/directory/xyz", "some-mod")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Download directory does not exist")
}

func TestMODDownloadRejectsMODDirAsTarget(t *testing.T) {
	s := newSandbox(t)

	_, err := runCLI(t, "mod", "download", "-d", filepath.Join(s.root, "factorio", "mods"), "some-mod")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Cannot download to MOD directory")
}

func TestDefaultFactorioVersion(t *testing.T) {
	baseSandbox(t)

	application, err := app.New(app.Options{})
	require.NoError(t, err)

	version, err := defaultFactorioVersion(application)
	require.NoError(t, err)
	assert.Equal(t, "1.1", version) // base-info.json fixture is version 1.1.110
}

func TestFetchLocalStatusNotInstalled(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})

	application, err := app.New(app.Options{})
	require.NoError(t, err)

	status, err := fetchLocalStatus(application, mod.MOD{Name: "ghost"})
	require.NoError(t, err)
	assert.False(t, status.Installed)
	assert.Nil(t, status.LocalVersion)
}

func TestFetchLocalStatusInstalledAndEnabled(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "some-mod", "1.2.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "some-mod", enabled: true},
	)

	application, err := app.New(app.Options{})
	require.NoError(t, err)

	status, err := fetchLocalStatus(application, mod.MOD{Name: "some-mod"})
	require.NoError(t, err)
	assert.True(t, status.Installed)
	assert.True(t, status.Enabled)
	require.NotNil(t, status.LocalVersion)
	assert.Equal(t, "1.2.0", status.LocalVersion.String())
}
