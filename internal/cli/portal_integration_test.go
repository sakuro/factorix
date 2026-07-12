package cli

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Integration tests driving CLI commands against an httptest stand-in for
// the MOD Portal (see portal_mock_test.go), covering the seams that unit
// tests miss: request construction, JSON decoding, and error mapping for
// commands that actually talk to the portal.

func TestMODShowAgainstMockPortal(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice", Summary: "A test mod",
		// mod show hits the /full endpoint, which never carries
		// latest_release (confirmed against the live API — see
		// writeMOD); it always derives "latest" from Releases.
		Releases: []portalRelease{{Version: "1.2.0", InfoJSON: portalInfoJSON{FactorioVersion: "2.0"}}},
	})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "show", "some-mod")
	require.NoError(t, err)
	assert.Contains(t, out, "Some MOD")
	assert.Contains(t, out, "1.2.0")
	assert.Contains(t, out, "Not installed")
}

func TestMODShowJSONAgainstMockPortal(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice",
		Releases: []portalRelease{{Version: "1.2.0"}},
	})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "show", "some-mod", "--json")
	require.NoError(t, err)
	assert.Contains(t, out, `"latest_version": "1.2.0"`)
	assert.Contains(t, out, `"status": "not_installed"`)
}

func TestMODShowNotOnPortal(t *testing.T) {
	baseSandbox(t)
	portal := newMockPortal(t) // no mods registered
	portal.withPortal(t)

	_, err := runCLI(t, "mod", "show", "missing-mod")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "MOD not found on portal")
}

func TestMODShowInstalledVersionAgainstMockPortal(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "some-mod", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "some-mod", enabled: true})
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice",
		Releases: []portalRelease{{Version: "2.0.0"}},
	})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "show", "some-mod")
	require.NoError(t, err)
	assert.Contains(t, out, "Enabled")
	assert.Contains(t, out, "1.0.0 (update available)")
}

func TestMODSearchAgainstMockPortal(t *testing.T) {
	s := baseSandbox(t)
	_ = s
	portal := newMockPortal(t,
		portalMOD{Name: "alpha-mod", Title: "Alpha", Owner: "alice", LatestRelease: &portalRelease{Version: "1.0.0"}},
		portalMOD{Name: "beta-mod", Title: "Beta", Owner: "bob", LatestRelease: &portalRelease{Version: "2.0.0"}},
	)
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "search")
	require.NoError(t, err)
	assert.Contains(t, out, "alpha-mod")
	assert.Contains(t, out, "beta-mod")
	assert.Contains(t, out, "2 MOD(s) found")
}

func TestMODSearchJSONAgainstMockPortal(t *testing.T) {
	baseSandbox(t)
	portal := newMockPortal(t, portalMOD{Name: "alpha-mod", Title: "Alpha", Owner: "alice"})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "search", "--json")
	require.NoError(t, err)
	assert.Contains(t, out, `"name": "alpha-mod"`)
}

func TestMODInstallAgainstMockPortal(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})
	release := portalRelease{
		// SHA1 left blank: the downloader skips digest verification when
		// it's empty, and the fixture content's real digest isn't worth
		// wiring through here.
		Version: "1.2.0", FileName: "some-mod_1.2.0.zip",
		DownloadURL: "/download/some-mod_1.2.0.zip",
		InfoJSON:    portalInfoJSON{FactorioVersion: "2.0"},
	}
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice",
		// mod install hits /full, which never carries latest_release; it
		// resolves "@latest" from Releases by release date.
		Releases: []portalRelease{release},
	})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "install", "some-mod", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "Installed 1 MOD(s)")

	installedPath := filepath.Join(s.root, "factorio", "mods", "some-mod_1.2.0.zip")
	assert.FileExists(t, installedPath)
	assert.Equal(t, []string{"/download/some-mod_1.2.0.zip?token=test-token&username=test-user"}, portal.downloads)

	states := s.readMODList(t)
	assert.True(t, states["some-mod"])
}

func TestMODInstallPullsInRecommendedDependency(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})
	mainRelease := portalRelease{
		Version: "1.0.0", FileName: "some-mod_1.0.0.zip",
		DownloadURL: "/download/some-mod_1.0.0.zip",
		InfoJSON:    portalInfoJSON{FactorioVersion: "2.0", Dependencies: []string{"+ lib-mod"}},
	}
	libRelease := portalRelease{
		Version: "2.0.0", FileName: "lib-mod_2.0.0.zip",
		DownloadURL: "/download/lib-mod_2.0.0.zip",
		InfoJSON:    portalInfoJSON{FactorioVersion: "2.0"},
	}
	portal := newMockPortal(t,
		portalMOD{Name: "some-mod", Title: "Some MOD", Owner: "alice", Releases: []portalRelease{mainRelease}},
		portalMOD{Name: "lib-mod", Title: "Lib MOD", Owner: "alice", Releases: []portalRelease{libRelease}},
	)
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "install", "some-mod", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "Installed 2 MOD(s)")

	states := s.readMODList(t)
	assert.True(t, states["some-mod"])
	assert.True(t, states["lib-mod"])
}

func TestMODInstallEnablesDisabledRecommendedDependency(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "lib-mod", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "lib-mod", enabled: false})
	release := portalRelease{
		Version: "1.0.0", FileName: "some-mod_1.0.0.zip",
		DownloadURL: "/download/some-mod_1.0.0.zip",
		InfoJSON:    portalInfoJSON{FactorioVersion: "2.0", Dependencies: []string{"+ lib-mod"}},
	}
	portal := newMockPortal(t, portalMOD{Name: "some-mod", Title: "Some MOD", Owner: "alice", Releases: []portalRelease{release}})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "install", "some-mod", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "Installed 1 MOD(s)")
	assert.Contains(t, out, "Enabled 1 disabled dependency MOD(s)")

	states := s.readMODList(t)
	assert.True(t, states["some-mod"])
	assert.True(t, states["lib-mod"])
}

func TestMODInstallNotOnPortal(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})
	portal := newMockPortal(t)
	portal.withPortal(t)
	_ = s

	_, err := runCLI(t, "mod", "install", "missing-mod", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "MOD not found on portal")
}
