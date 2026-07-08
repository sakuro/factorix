package mod

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func fixturePath(t *testing.T, elems ...string) string {
	t.Helper()
	return filepath.Join(append([]string{"..", "..", "spec", "fixtures"}, elems...)...)
}

func TestLoadMODList(t *testing.T) {
	list, err := LoadMODList(fixturePath(t, "mod-list", "list.json"))
	require.NoError(t, err)

	require.Equal(t, 3, list.Len())

	var order []MOD
	for m := range list.MODs() {
		order = append(order, m)
	}
	assert.Equal(t, []MOD{{Name: "base"}, {Name: "enabled-mod"}, {Name: "disabled-mod"}}, order)

	enabled, err := list.Enabled(MOD{Name: "enabled-mod"})
	require.NoError(t, err)
	assert.True(t, enabled)

	enabled, err = list.Enabled(MOD{Name: "disabled-mod"})
	require.NoError(t, err)
	assert.False(t, enabled)

	version, err := list.Version(MOD{Name: "enabled-mod"})
	require.NoError(t, err)
	require.NotNil(t, version)
	assert.Equal(t, MODVersion{Major: 1}, *version)

	version, err = list.Version(MOD{Name: "disabled-mod"})
	require.NoError(t, err)
	assert.Nil(t, version)
}

func TestLoadMODListBaseDisabled(t *testing.T) {
	_, err := LoadMODList(fixturePath(t, "mod-list", "invalid_base_disabled.json"))
	require.ErrorIs(t, err, ErrCannotDisableBaseMOD)
}

func TestMODListSaveRoundTrip(t *testing.T) {
	list, err := LoadMODList(fixturePath(t, "mod-list", "list.json"))
	require.NoError(t, err)

	path := filepath.Join(t.TempDir(), "mod-list.json")
	require.NoError(t, list.Save(path))

	reloaded, err := LoadMODList(path)
	require.NoError(t, err)
	assert.Equal(t, list, reloaded)

	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.JSONEq(t, `{
		"mods": [
			{"name": "base", "enabled": true},
			{"name": "enabled-mod", "enabled": true, "version": "1.0.0"},
			{"name": "disabled-mod", "enabled": false}
		]
	}`, string(data))
}

func TestMODListAdd(t *testing.T) {
	list := NewMODList()
	require.NoError(t, list.Add(MOD{Name: "base"}, MODState{Enabled: true}))
	require.NoError(t, list.Add(MOD{Name: "some-mod"}, MODState{Enabled: true}))
	assert.True(t, list.Contains(MOD{Name: "some-mod"}))

	err := list.Add(MOD{Name: "base"}, MODState{Enabled: false})
	require.ErrorIs(t, err, ErrCannotDisableBaseMOD)

	// Replacing an existing entry must not duplicate it in the order.
	require.NoError(t, list.Add(MOD{Name: "some-mod"}, MODState{Enabled: false}))
	assert.Equal(t, 2, list.Len())
}

func TestMODListRemove(t *testing.T) {
	list := NewMODList()
	require.NoError(t, list.Add(MOD{Name: "base"}, MODState{Enabled: true}))
	require.NoError(t, list.Add(MOD{Name: "space-age"}, MODState{Enabled: true}))
	require.NoError(t, list.Add(MOD{Name: "some-mod"}, MODState{Enabled: true}))

	require.ErrorIs(t, list.Remove(MOD{Name: "base"}), ErrCannotRemoveBaseMOD)
	require.ErrorIs(t, list.Remove(MOD{Name: "space-age"}), ErrCannotRemoveExpansionMOD)

	require.NoError(t, list.Remove(MOD{Name: "some-mod"}))
	assert.False(t, list.Contains(MOD{Name: "some-mod"}))

	require.NoError(t, list.Remove(MOD{Name: "not-there"}))
}

func TestMODListEnableDisable(t *testing.T) {
	version := MODVersion{Major: 1, Minor: 2, Patch: 3}
	list := NewMODList()
	require.NoError(t, list.Add(MOD{Name: "base"}, MODState{Enabled: true}))
	require.NoError(t, list.Add(MOD{Name: "some-mod"}, MODState{Enabled: true, Version: &version}))

	require.NoError(t, list.Disable(MOD{Name: "some-mod"}))
	enabled, err := list.Enabled(MOD{Name: "some-mod"})
	require.NoError(t, err)
	assert.False(t, enabled)

	// Version survives state changes.
	got, err := list.Version(MOD{Name: "some-mod"})
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, version, *got)

	require.NoError(t, list.Enable(MOD{Name: "some-mod"}))
	enabled, err = list.Enabled(MOD{Name: "some-mod"})
	require.NoError(t, err)
	assert.True(t, enabled)

	require.ErrorIs(t, list.Disable(MOD{Name: "base"}), ErrCannotDisableBaseMOD)
	require.ErrorIs(t, list.Enable(MOD{Name: "not-there"}), ErrMODNotInList)
	require.ErrorIs(t, list.Disable(MOD{Name: "not-there"}), ErrMODNotInList)

	_, err = list.Enabled(MOD{Name: "not-there"})
	require.ErrorIs(t, err, ErrMODNotInList)
	_, err = list.Version(MOD{Name: "not-there"})
	require.ErrorIs(t, err, ErrMODNotInList)
}
