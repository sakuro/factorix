package platform

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// factorioLibraryVDF returns libraryfolders.vdf content for a single
// library at libraryPath that contains Factorio.
func factorioLibraryVDF(libraryPath string) string {
	return `"libraryfolders"
{
	"0"
	{
		"path"		"` + libraryPath + `"
		"apps"
		{
			"427520"		"654321000"
		}
	}
}
`
}

// writeLibraryFolders writes content to <steamRoot>/steamapps/libraryfolders.vdf.
func writeLibraryFolders(t *testing.T, steamRoot, content string) {
	t.Helper()
	dir := filepath.Join(steamRoot, "steamapps")
	require.NoError(t, os.MkdirAll(dir, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "libraryfolders.vdf"), []byte(content), 0o644))
}

func TestFindFactorioDirSingleLibrary(t *testing.T) {
	root := t.TempDir()
	writeLibraryFolders(t, root, factorioLibraryVDF(root))

	dir, err := findFactorioDir(root)
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(root, "steamapps", "common", "Factorio"), dir)
}

func TestFindFactorioDirNonDefaultLibrary(t *testing.T) {
	root := t.TempDir()
	otherLibrary := filepath.Join(t.TempDir(), "SteamLibrary")
	writeLibraryFolders(t, root, `"libraryfolders"
{
	"0"
	{
		"path"		"`+root+`"
		"apps"
		{
			"228980"		"476349747"
		}
	}
	"1"
	{
		"path"		"`+otherLibrary+`"
		"apps"
		{
			"427520"		"654321000"
		}
	}
}
`)

	dir, err := findFactorioDir(root)
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(otherLibrary, "steamapps", "common", "Factorio"), dir)
}

func TestFindFactorioDirNotFound(t *testing.T) {
	root := t.TempDir()
	writeLibraryFolders(t, root, `"libraryfolders"
{
	"0"
	{
		"path"		"`+root+`"
		"apps"
		{
			"228980"		"476349747"
		}
	}
}
`)

	_, err := findFactorioDir(root)
	require.ErrorIs(t, err, ErrFactorioNotFound)
}

func TestFindFactorioDirMissingFile(t *testing.T) {
	root := t.TempDir()

	_, err := findFactorioDir(root)
	require.Error(t, err)
}

func TestFindFactorioDirEscapedBackslashes(t *testing.T) {
	root := t.TempDir()
	writeLibraryFolders(t, root, `"libraryfolders"
{
	"0"
	{
		"path"		"C:\\Program Files (x86)\\Steam"
		"apps"
		{
			"427520"		"654321000"
		}
	}
}
`)

	dir, err := findFactorioDir(root)
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(`C:\Program Files (x86)\Steam`, "steamapps", "common", "Factorio"), dir)
}
