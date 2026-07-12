package cli

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/save"
)

func TestMODSyncInstallsMissingMODAgainstMockPortal(t *testing.T) {
	s, savePath := syncSandbox(t, []save.MODEntry{{Name: "some-mod", Version: mustVersion(t, "1.0.0")}}, nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice",
		// mod sync (unlike install/download) trusts latest_release first
		// (see findSyncRelease) — set both so the test exercises the real
		// full-endpoint shape either way.
		Releases: []portalRelease{{
			Version: "1.0.0", FileName: "some-mod_1.0.0.zip", DownloadURL: "/download/some-mod_1.0.0.zip",
		}},
	})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "sync", savePath, "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "Installed 1 MOD(s)")
	assert.FileExists(t, filepath.Join(s.root, "factorio", "mods", "some-mod_1.0.0.zip"))

	states := s.readMODList(t)
	assert.True(t, states["some-mod"])
}

func TestMODSyncPullsInRecommendedDependencyAgainstMockPortal(t *testing.T) {
	s, savePath := syncSandbox(t, []save.MODEntry{{Name: "some-mod", Version: mustVersion(t, "1.0.0")}}, nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})
	portal := newMockPortal(t,
		portalMOD{
			Name: "some-mod", Title: "Some MOD", Owner: "alice",
			Releases: []portalRelease{{
				Version: "1.0.0", FileName: "some-mod_1.0.0.zip", DownloadURL: "/download/some-mod_1.0.0.zip",
				InfoJSON: portalInfoJSON{Dependencies: []string{"+ lib-mod"}},
			}},
		},
		portalMOD{
			Name: "lib-mod", Title: "Lib MOD", Owner: "alice",
			Releases: []portalRelease{{
				Version: "2.0.0", FileName: "lib-mod_2.0.0.zip", DownloadURL: "/download/lib-mod_2.0.0.zip",
			}},
		},
	)
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "sync", savePath, "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "Installed 2 MOD(s)")
	assert.FileExists(t, filepath.Join(s.root, "factorio", "mods", "some-mod_1.0.0.zip"))
	assert.FileExists(t, filepath.Join(s.root, "factorio", "mods", "lib-mod_2.0.0.zip"))

	states := s.readMODList(t)
	assert.True(t, states["some-mod"])
	assert.True(t, states["lib-mod"])
}

func TestMODSyncStrictVersionAgainstMockPortal(t *testing.T) {
	s, savePath := syncSandbox(t, []save.MODEntry{{Name: "some-mod", Version: mustVersion(t, "1.0.0")}}, nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice",
		Releases: []portalRelease{
			{Version: "1.0.0", FileName: "some-mod_1.0.0.zip", DownloadURL: "/download/some-mod_1.0.0.zip"},
			{Version: "2.0.0", FileName: "some-mod_2.0.0.zip", DownloadURL: "/download/some-mod_2.0.0.zip"},
		},
	})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "sync", savePath, "-y", "--strict-version")
	require.NoError(t, err)
	assert.Contains(t, out, "Installed 1 MOD(s)")
	assert.FileExists(t, filepath.Join(s.root, "factorio", "mods", "some-mod_1.0.0.zip"))
	assert.NoFileExists(t, filepath.Join(s.root, "factorio", "mods", "some-mod_2.0.0.zip"))
}

func TestMODSyncMissingReleaseFails(t *testing.T) {
	s, savePath := syncSandbox(t, []save.MODEntry{{Name: "some-mod", Version: mustVersion(t, "1.0.0")}}, nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice",
		Releases: []portalRelease{{Version: "9.9.9", FileName: "some-mod_9.9.9.zip"}},
	})
	portal.withPortal(t)

	_, err := runCLI(t, "mod", "sync", savePath, "-y", "--strict-version")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Release not found for some-mod@1.0.0")
}
