package settings

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/serdes"
)

func TestDumpJSON(t *testing.T) {
	data, err := sampleSettings(t).DumpJSON()
	require.NoError(t, err)

	assert.JSONEq(t, `{
		"game_version": "2.0.72",
		"startup": {
			"bool-setting": true,
			"number-setting": 0.5,
			"string-setting": "hello",
			"int-setting": -42
		},
		"runtime-global": {
			"color-setting": {"r": 1.0, "g": 0.5}
		}
	}`, string(data))

	// An integral double must keep its decimal point so RestoreJSON maps it
	// back to Number, not SignedInt.
	assert.Contains(t, string(data), `"r": 1.0`)
}

func TestJSONRoundTrip(t *testing.T) {
	ms := sampleSettings(t)

	data, err := ms.DumpJSON()
	require.NoError(t, err)

	restored, err := RestoreJSON(data)
	require.NoError(t, err)

	assert.Equal(t, ms.GameVersion, restored.GameVersion)
	for section := range ms.Sections() {
		restoredSection, err := restored.Section(section.Name())
		require.NoError(t, err)
		require.Equal(t, section.Len(), restoredSection.Len(), section.Name())
		for key, value := range section.All() {
			got, ok := restoredSection.Get(key)
			require.True(t, ok, key)
			assert.Equal(t, value, got, key)
		}
	}
}

func TestRestoreJSONIntegersBecomeSignedInt(t *testing.T) {
	ms, err := RestoreJSON([]byte(`{
		"game_version": "2.0.72",
		"startup": {"count": 7, "ratio": 7.0}
	}`))
	require.NoError(t, err)

	startup, err := ms.Section("startup")
	require.NoError(t, err)

	count, ok := startup.Get("count")
	require.True(t, ok)
	assert.Equal(t, serdes.SignedInt(7), count)

	ratio, ok := startup.Get("ratio")
	require.True(t, ok)
	assert.Equal(t, serdes.Number(7.0), ratio)
}

func TestRestoreJSONMissingGameVersion(t *testing.T) {
	_, err := RestoreJSON([]byte(`{"startup": {}}`))
	require.ErrorIs(t, err, ErrMalformedSettings)
}

func TestRestoreJSONIgnoresUnknownKeys(t *testing.T) {
	ms, err := RestoreJSON([]byte(`{"game_version": "2.0.72", "comment": ["ignored"]}`))
	require.NoError(t, err)
	assert.Equal(t, "2.0.72", ms.GameVersion.String())
}
