package save

import (
	"archive/zip"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
)

func TestLoad(t *testing.T) {
	f, err := Load(filepath.Join("..", "..", "testdata", "test-save.zip"))
	require.NoError(t, err)

	assert.Equal(t, "2.0.72", f.Version.String())

	require.NotEmpty(t, f.MODs)
	var base *MODEntry
	for i := range f.MODs {
		if f.MODs[i].Name == "base" {
			base = &f.MODs[i]
			break
		}
	}
	require.NotNil(t, base, "save must record the base MOD")
	assert.Equal(t, "2.0.72", base.Version.String())

	require.NotNil(t, f.StartupSettings)
	assert.Equal(t, "startup", f.StartupSettings.Name())
	assert.Positive(t, f.StartupSettings.Len())
}

func TestLoadNotAZip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "not-a-save.zip")
	require.NoError(t, os.WriteFile(path, []byte("plain text"), 0o644))

	_, err := Load(path)
	var ffe *mod.FileFormatError
	require.ErrorAs(t, err, &ffe)
}

func TestLoadNoLevelFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "no-level.zip")
	f, err := os.Create(path)
	require.NoError(t, err)
	zw := zip.NewWriter(f)
	w, err := zw.Create("some-save/other.dat")
	require.NoError(t, err)
	_, err = w.Write([]byte("irrelevant"))
	require.NoError(t, err)
	require.NoError(t, zw.Close())
	require.NoError(t, f.Close())

	_, err = Load(path)
	var ffe *mod.FileFormatError
	require.ErrorAs(t, err, &ffe)
	assert.Contains(t, ffe.Msg, "not found")
}
