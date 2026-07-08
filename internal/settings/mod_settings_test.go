package settings

import (
	"bytes"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/serdes"
)

func sampleSettings(t *testing.T) *MODSettings {
	t.Helper()
	ms := New(mod.GameVersion{Major: 2, Minor: 0, Patch: 72})

	startup, err := ms.Section("startup")
	require.NoError(t, err)
	startup.Set("bool-setting", serdes.Bool(true))
	startup.Set("number-setting", serdes.Number(0.5))
	startup.Set("string-setting", serdes.String("hello"))
	startup.Set("int-setting", serdes.SignedInt(-42))

	global, err := ms.Section("runtime-global")
	require.NoError(t, err)
	global.Set("color-setting", serdes.Dict(
		serdes.DictEntry{Key: "r", Value: serdes.Number(1)},
		serdes.DictEntry{Key: "g", Value: serdes.Number(0.5)},
	))

	return ms
}

func TestMODSettingsRoundTrip(t *testing.T) {
	ms := sampleSettings(t)

	var buf bytes.Buffer
	require.NoError(t, ms.Save(&buf))
	first := buf.Bytes()

	loaded, err := Load(bytes.NewReader(first))
	require.NoError(t, err)
	assert.Equal(t, ms.GameVersion, loaded.GameVersion)

	startup, err := loaded.Section("startup")
	require.NoError(t, err)
	assert.Equal(t, 4, startup.Len())
	v, ok := startup.Get("number-setting")
	require.True(t, ok)
	assert.Equal(t, serdes.Number(0.5), v)

	// The empty runtime-per-user section still exists after loading.
	perUser, err := loaded.Section("runtime-per-user")
	require.NoError(t, err)
	assert.Equal(t, 0, perUser.Len())

	var buf2 bytes.Buffer
	require.NoError(t, loaded.Save(&buf2))
	assert.Equal(t, first, buf2.Bytes())
}

func TestLoadExtraData(t *testing.T) {
	var buf bytes.Buffer
	require.NoError(t, sampleSettings(t).Save(&buf))
	buf.WriteByte(0x00)

	_, err := Load(bytes.NewReader(buf.Bytes()))
	require.ErrorIs(t, err, ErrExtraData)
}

func TestLoadInvalidSectionName(t *testing.T) {
	var buf bytes.Buffer
	s := serdes.NewSerializer(&buf)
	require.NoError(t, s.WriteGameVersion(mod.GameVersion{Major: 2}))
	require.NoError(t, s.WriteBool(false))
	require.NoError(t, s.WritePropertyTree(serdes.Dict(
		serdes.DictEntry{Key: "bogus-section", Value: serdes.Dict()},
	)))

	_, err := Load(bytes.NewReader(buf.Bytes()))
	require.ErrorIs(t, err, ErrInvalidSectionName)
}

func TestNewSectionInvalidName(t *testing.T) {
	_, err := NewSection("bogus")
	require.ErrorIs(t, err, ErrInvalidSectionName)
}

func TestMODSettingsSectionInvalidName(t *testing.T) {
	ms := New(mod.GameVersion{Major: 2})
	_, err := ms.Section("bogus")
	require.ErrorIs(t, err, ErrInvalidSectionName)
}
