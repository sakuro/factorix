package cli

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMODDownloadAgainstMockPortal(t *testing.T) {
	s := baseSandbox(t)
	dir := filepath.Join(s.root, "downloads")
	require.NoError(t, os.MkdirAll(dir, 0o755))
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice",
		Releases: []portalRelease{{
			Version: "1.0.0", FileName: "some-mod_1.0.0.zip", DownloadURL: "/download/some-mod_1.0.0.zip",
			InfoJSON: portalInfoJSON{FactorioVersion: "2.0"},
		}},
	})
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "download", "some-mod", "-d", dir)
	require.NoError(t, err)
	assert.Contains(t, out, "Downloaded 1 MOD(s)")
	assert.FileExists(t, filepath.Join(dir, "some-mod_1.0.0.zip"))
}

func TestMODDownloadRecursiveAgainstMockPortal(t *testing.T) {
	s := baseSandbox(t)
	dir := filepath.Join(s.root, "downloads")
	require.NoError(t, os.MkdirAll(dir, 0o755))
	portal := newMockPortal(t,
		portalMOD{
			Name: "top-mod", Title: "Top MOD", Owner: "alice",
			Releases: []portalRelease{{
				Version: "1.0.0", FileName: "top-mod_1.0.0.zip", DownloadURL: "/download/top-mod_1.0.0.zip",
				InfoJSON: portalInfoJSON{FactorioVersion: "2.0", Dependencies: []string{"base", "dep-mod >= 1.0.0"}},
			}},
		},
		portalMOD{
			Name: "dep-mod", Title: "Dep MOD", Owner: "bob",
			Releases: []portalRelease{{
				Version: "1.2.0", FileName: "dep-mod_1.2.0.zip", DownloadURL: "/download/dep-mod_1.2.0.zip",
				InfoJSON: portalInfoJSON{FactorioVersion: "2.0"},
			}},
		},
	)
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "download", "top-mod", "-d", dir, "-r")
	require.NoError(t, err)
	assert.Contains(t, out, "Downloaded 2 MOD(s)")
	assert.FileExists(t, filepath.Join(dir, "top-mod_1.0.0.zip"))
	assert.FileExists(t, filepath.Join(dir, "dep-mod_1.2.0.zip"))
}

func TestMODDownloadRecursiveSkipsIncompatibleDependency(t *testing.T) {
	s := baseSandbox(t)
	dir := filepath.Join(s.root, "downloads")
	require.NoError(t, os.MkdirAll(dir, 0o755))
	portal := newMockPortal(t,
		portalMOD{
			Name: "top-mod", Title: "Top MOD", Owner: "alice",
			Releases: []portalRelease{{
				Version: "1.0.0", FileName: "top-mod_1.0.0.zip", DownloadURL: "/download/top-mod_1.0.0.zip",
				InfoJSON: portalInfoJSON{FactorioVersion: "2.0", Dependencies: []string{"dep-mod >= 9.0.0"}},
			}},
		},
		portalMOD{
			Name: "dep-mod", Title: "Dep MOD", Owner: "bob",
			Releases: []portalRelease{{Version: "1.0.0", FileName: "dep-mod_1.0.0.zip", DownloadURL: "/download/dep-mod_1.0.0.zip"}},
		},
	)
	portal.withPortal(t)

	out, err := runCLI(t, "mod", "download", "top-mod", "-d", dir, "-r")
	require.NoError(t, err)
	assert.Contains(t, out, "Downloaded 1 MOD(s)")
	assert.FileExists(t, filepath.Join(dir, "top-mod_1.0.0.zip"))
	assert.NoFileExists(t, filepath.Join(dir, "dep-mod_1.0.0.zip"))
}

func TestMODDownloadNotOnPortal(t *testing.T) {
	s := baseSandbox(t)
	dir := filepath.Join(s.root, "downloads")
	require.NoError(t, os.MkdirAll(dir, 0o755))
	portal := newMockPortal(t)
	portal.withPortal(t)

	_, err := runCLI(t, "mod", "download", "missing-mod", "-d", dir)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "MOD not found on portal")
}
