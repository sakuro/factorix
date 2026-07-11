package cli

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMODUpdateAgainstMockPortal(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "some-mod", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "some-mod", enabled: true})
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice",
		Releases: []portalRelease{{
			Version: "1.1.0", FileName: "some-mod_1.1.0.zip", DownloadURL: "/download/some-mod_1.1.0.zip",
			InfoJSON: portalInfoJSON{FactorioVersion: "2.0"},
		}},
	})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "update", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "Updated 1 MOD(s)")

	states := s.readMODList(t)
	assert.True(t, states["some-mod"])
}

func TestMODUpdateAlreadyUpToDate(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "some-mod", "1.1.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "some-mod", enabled: true})
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice",
		Releases: []portalRelease{{Version: "1.1.0", FileName: "some-mod_1.1.0.zip"}},
	})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "update", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "All MOD(s) are up to date")
}

func TestMODUpdateSkipsMODMissingFromPortal(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "removed-mod", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "removed-mod", enabled: true})
	portal := newMockPortal(t) // removed-mod no longer exists on the portal
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "update", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "All MOD(s) are up to date")
}
