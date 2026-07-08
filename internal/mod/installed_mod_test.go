package mod

import (
	"archive/zip"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const testInfoJSON = `{"name": "test-mod", "version": "1.2.3", "title": "Test MOD", "author": "someone"}`

func writeMODZip(t *testing.T, dir, filename string) string {
	t.Helper()
	path := filepath.Join(dir, filename)
	f, err := os.Create(path)
	require.NoError(t, err)
	defer f.Close()

	zw := zip.NewWriter(f)
	w, err := zw.Create("test-mod_1.2.3/info.json")
	require.NoError(t, err)
	_, err = w.Write([]byte(testInfoJSON))
	require.NoError(t, err)
	require.NoError(t, zw.Close())
	return path
}

func writeMODDirectory(t *testing.T, dir, name string) string {
	t.Helper()
	path := filepath.Join(dir, name)
	require.NoError(t, os.Mkdir(path, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(path, "info.json"), []byte(testInfoJSON), 0o644))
	return path
}

func TestInstalledMODFromZIP(t *testing.T) {
	path := writeMODZip(t, t.TempDir(), "test-mod_1.2.3.zip")

	im, err := InstalledMODFromZIP(path)
	require.NoError(t, err)
	assert.Equal(t, MOD{Name: "test-mod"}, im.MOD)
	assert.Equal(t, MODVersion{Major: 1, Minor: 2, Patch: 3}, im.Version)
	assert.Equal(t, FormZIP, im.Form)
	assert.Equal(t, path, im.Path)
	assert.Equal(t, "Test MOD", im.Info.Title)
}

func TestInstalledMODFromZIPFilenameMismatch(t *testing.T) {
	path := writeMODZip(t, t.TempDir(), "wrong-name_9.9.9.zip")

	_, err := InstalledMODFromZIP(path)
	var ffe *FileFormatError
	require.ErrorAs(t, err, &ffe)
	assert.Contains(t, ffe.Msg, "filename mismatch")
}

func TestInstalledMODFromZIPInvalidZip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "test-mod_1.2.3.zip")
	require.NoError(t, os.WriteFile(path, []byte("not a zip"), 0o644))

	_, err := InstalledMODFromZIP(path)
	var ffe *FileFormatError
	require.ErrorAs(t, err, &ffe)
}

func TestInstalledMODFromDirectory(t *testing.T) {
	for _, dirname := range []string{"test-mod", "test-mod_1.2.3"} {
		t.Run(dirname, func(t *testing.T) {
			path := writeMODDirectory(t, t.TempDir(), dirname)

			im, err := InstalledMODFromDirectory(path)
			require.NoError(t, err)
			assert.Equal(t, MOD{Name: "test-mod"}, im.MOD)
			assert.Equal(t, FormDirectory, im.Form)
		})
	}
}

func TestInstalledMODFromDirectoryNameMismatch(t *testing.T) {
	path := writeMODDirectory(t, t.TempDir(), "other-name")

	_, err := InstalledMODFromDirectory(path)
	var ffe *FileFormatError
	require.ErrorAs(t, err, &ffe)
	assert.Contains(t, ffe.Msg, "directory name mismatch")
}

func TestInstalledMODFromDirectoryMissingInfoJSON(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test-mod")
	require.NoError(t, os.Mkdir(path, 0o755))

	_, err := InstalledMODFromDirectory(path)
	var ffe *FileFormatError
	require.ErrorAs(t, err, &ffe)
	assert.Contains(t, ffe.Msg, "missing info.json")
}

func TestInstalledMODCompare(t *testing.T) {
	v1 := InstalledMOD{Version: MODVersion{Major: 1}, Form: FormZIP}
	v2 := InstalledMOD{Version: MODVersion{Major: 2}, Form: FormZIP}
	v2dir := InstalledMOD{Version: MODVersion{Major: 2}, Form: FormDirectory}

	assert.Equal(t, -1, v1.Compare(v2))
	assert.Equal(t, 1, v2.Compare(v1))
	// Directory form wins over ZIP at the same version.
	assert.Equal(t, -1, v2.Compare(v2dir))
	assert.Equal(t, 0, v2.Compare(v2))
}
