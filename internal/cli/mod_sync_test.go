package cli

import (
	"archive/zip"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/save"
	"github.com/sakuro/factorix/internal/serdes"
	"github.com/sakuro/factorix/internal/settings"
)

// writeSyncSave builds a minimal save zip the save package can parse:
// game version, the fixed header fields, the MOD entries, and a startup
// settings property tree.
func writeSyncSave(t *testing.T, path string, mods []save.MODEntry, startup []serdes.DictEntry) {
	t.Helper()

	f, err := os.Create(path)
	require.NoError(t, err)
	zw := zip.NewWriter(f)
	w, err := zw.Create("test-save/level-init.dat")
	require.NoError(t, err)

	s := serdes.NewSerializer(w)
	version, err := mod.ParseGameVersion("2.0.72-0")
	require.NoError(t, err)
	require.NoError(t, s.WriteGameVersion(version))
	require.NoError(t, s.WriteU8(0))       // unknown
	require.NoError(t, s.WriteStr(""))     // campaign
	require.NoError(t, s.WriteStr(""))     // level_name
	require.NoError(t, s.WriteStr("base")) // base_mod
	require.NoError(t, s.WriteU8(1))       // difficulty
	require.NoError(t, s.WriteBool(false)) // finished
	require.NoError(t, s.WriteBool(false)) // player_won
	require.NoError(t, s.WriteStr(""))     // next_level
	require.NoError(t, s.WriteBool(false)) // can_continue
	require.NoError(t, s.WriteBool(false)) // finished_but_continuing
	require.NoError(t, s.WriteBool(false)) // saving_replay
	require.NoError(t, s.WriteBool(false)) // allow_non_admin_debug_options
	require.NoError(t, s.WriteMODVersion(mod.MODVersion{Major: 2}))
	require.NoError(t, s.WriteU16(0)) // loaded_from_build
	require.NoError(t, s.WriteU8(0))  // allowed_commands
	require.NoError(t, s.WriteBool(false))
	require.NoError(t, s.WriteU32(0))
	require.NoError(t, s.WriteBool(false))

	require.NoError(t, s.WriteOptimU32(uint32(len(mods))))
	for _, entry := range mods {
		require.NoError(t, s.WriteStr(entry.Name))
		require.NoError(t, s.WriteMODVersion(entry.Version))
		require.NoError(t, s.WriteU32(0)) // CRC
	}
	require.NoError(t, s.WriteU32(0)) // unknown

	wrapped := make([]serdes.DictEntry, len(startup))
	for i, entry := range startup {
		wrapped[i] = serdes.DictEntry{Key: entry.Key, Value: serdes.Dict(serdes.DictEntry{Key: "value", Value: entry.Value})}
	}
	require.NoError(t, s.WritePropertyTree(serdes.Dict(wrapped...)))

	require.NoError(t, zw.Close())
	require.NoError(t, f.Close())
}

func mustVersion(t *testing.T, s string) mod.MODVersion {
	t.Helper()
	v, err := mod.ParseMODVersion(s)
	require.NoError(t, err)
	return v
}

// syncSandbox sets up base + the given installed/listed MODs and returns
// the path of a save file recording saveMODs (always including base).
func syncSandbox(t *testing.T, saveMODs []save.MODEntry, startup []serdes.DictEntry) (*sandbox, string) {
	t.Helper()
	s := baseSandbox(t)
	savePath := filepath.Join(s.root, "the-save.zip")
	entries := append([]save.MODEntry{{Name: "base", Version: mustVersion(t, "2.0.72")}}, saveMODs...)
	writeSyncSave(t, savePath, entries, startup)
	return s, savePath
}

func TestMODSyncNothingToChange(t *testing.T) {
	s, savePath := syncSandbox(t, []save.MODEntry{{Name: "some-mod", Version: mustVersion(t, "1.0.0")}}, nil)
	s.writeInstalledMOD(t, "some-mod", "1.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "some-mod", enabled: true},
	)
	// mod-settings.dat with no startup keys to sync: write via updateStartupSettings.
	settingsPath := filepath.Join(s.root, "factorio", "mods", "mod-settings.dat")
	version, err := mod.ParseGameVersion("2.0.72")
	require.NoError(t, err)
	require.NoError(t, settings.New(version).SaveFile(settingsPath))

	out, err := runCLI(t, "mod", "sync", savePath, "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "ℹ Nothing to change\n")
	assert.Contains(t, out, "MOD(s): 2)\n")
}

func TestMODSyncEnableDisableAndSettings(t *testing.T) {
	startup := []serdes.DictEntry{{Key: "some-setting", Value: serdes.Bool(true)}}
	s, savePath := syncSandbox(t, []save.MODEntry{{Name: "wanted-mod", Version: mustVersion(t, "1.0.0")}}, startup)
	s.writeInstalledMOD(t, "wanted-mod", "1.0.0", nil)
	s.writeInstalledMOD(t, "extra-mod", "2.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "wanted-mod", enabled: false},
		modListEntry{name: "extra-mod", enabled: true},
	)

	out, err := runCLI(t, "mod", "sync", savePath, "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "  Enable:\n    - wanted-mod\n")
	assert.Contains(t, out, "  Disable:\n    - extra-mod (not listed in save file)\n")
	assert.Contains(t, out, "  Update startup settings\n")
	assert.Contains(t, out, "✓ Updated mod-list.json\n")
	assert.Contains(t, out, "✓ Updated mod-settings.dat\n")
	assert.Contains(t, out, "✓ Sync completed successfully\n")

	states := s.readMODList(t)
	assert.True(t, states["wanted-mod"])
	assert.False(t, states["extra-mod"])

	// The startup settings landed in the newly created mod-settings.dat.
	settingsPath := filepath.Join(s.root, "factorio", "mods", "mod-settings.dat")
	modSettings, err := settings.LoadFile(settingsPath)
	require.NoError(t, err)
	startupSection, err := modSettings.Section("startup")
	require.NoError(t, err)
	value, ok := startupSection.Get("some-setting")
	require.True(t, ok)
	assert.True(t, value.Equal(serdes.Bool(true)))
}

func TestMODSyncKeepUnlisted(t *testing.T) {
	s, savePath := syncSandbox(t, nil, nil)
	s.writeInstalledMOD(t, "extra-mod", "2.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "extra-mod", enabled: true},
	)

	out, err := runCLI(t, "mod", "sync", savePath, "-y", "--keep-unlisted")
	require.NoError(t, err)
	assert.NotContains(t, out, "Disable:")
	// Settings still count as changed (no mod-settings.dat yet).
	assert.Contains(t, out, "✓ Updated mod-settings.dat\n")

	states := s.readMODList(t)
	assert.True(t, states["extra-mod"])
}

func TestMODSyncStrictVersionDeletesNewerPackages(t *testing.T) {
	s, savePath := syncSandbox(t, []save.MODEntry{{Name: "some-mod", Version: mustVersion(t, "1.0.0")}}, nil)
	s.writeInstalledMOD(t, "some-mod", "1.0.0", nil)
	// A newer zip alongside the wanted version must be deleted.
	newerZip := filepath.Join(s.root, "factorio", "mods", "some-mod_2.0.0.zip")
	writeMODZip(t, newerZip, "some-mod", "2.0.0")
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "some-mod", enabled: true})

	out, err := runCLI(t, "mod", "sync", savePath, "-y", "--strict-version")
	require.NoError(t, err)
	assert.Contains(t, out, "  Delete (newer than save version):\n    - some-mod@2.0.0 (some-mod_2.0.0.zip)\n")
	// mod-list.json records no version, so the current version falls back
	// to the newest installed package (the 2.0.0 zip).
	assert.Contains(t, out, "  Update:\n    - some-mod (2.0.0 → 1.0.0)\n")
	assert.Contains(t, out, "✓ Deleted 1 MOD package(s)\n")
	assert.NoFileExists(t, newerZip)
}

func TestMODSyncPromptDecline(t *testing.T) {
	s, savePath := syncSandbox(t, nil, nil)
	s.writeInstalledMOD(t, "extra-mod", "2.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "extra-mod", enabled: true})

	out, err := runCLIWithStdin(t, "n\n", "mod", "sync", savePath)
	require.NoError(t, err)
	assert.Contains(t, out, "Do you want to apply these changes?")
	assert.NotContains(t, out, "Sync completed successfully")

	states := s.readMODList(t)
	assert.True(t, states["extra-mod"])
}

func TestMODSyncRequiresGameStopped(t *testing.T) {
	s, savePath := syncSandbox(t, nil, nil)
	require.NoError(t, os.WriteFile(filepath.Join(s.root, "factorio", ".lock"), nil, 0o644))

	_, err := runCLI(t, "mod", "sync", savePath, "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "running")
}

// writeMODZip writes a minimal valid MOD zip (name_version.zip layout).
func writeMODZip(t *testing.T, path, name, version string) {
	t.Helper()
	f, err := os.Create(path)
	require.NoError(t, err)
	zw := zip.NewWriter(f)
	w, err := zw.Create(name + "/info.json")
	require.NoError(t, err)
	_, err = w.Write([]byte(`{"name": "` + name + `", "version": "` + version + `", "title": "` + name + `", "author": "test", "factorio_version": "2.0"}`))
	require.NoError(t, err)
	require.NoError(t, zw.Close())
	require.NoError(t, f.Close())
}

func TestFindSyncRelease(t *testing.T) {
	v1 := mustVersion(t, "1.0.0")
	v2 := mustVersion(t, "2.0.0")
	info := &api.MODInfo{Releases: []api.Release{{Version: v1}, {Version: v2}}}

	// Strict: exact version or nothing.
	release := findSyncRelease(info, modSpec{Version: v1})
	require.NotNil(t, release)
	assert.Equal(t, v1, release.Version)
	assert.Nil(t, findSyncRelease(info, modSpec{Version: mustVersion(t, "9.9.9")}))

	// Latest: latest_release wins, highest version as fallback.
	release = findSyncRelease(info, modSpec{Latest: true})
	require.NotNil(t, release)
	assert.Equal(t, v2, release.Version)
	withLatest := &api.MODInfo{Releases: info.Releases, LatestRelease: &api.Release{Version: v1}}
	assert.Equal(t, v1, findSyncRelease(withLatest, modSpec{Latest: true}).Version)
}

func TestPlanMODListChangesStrictVersion(t *testing.T) {
	modList := mod.NewMODList()
	v1 := mustVersion(t, "1.0.0")
	require.NoError(t, modList.Add(mod.MOD{Name: "base"}, mod.MODState{Enabled: true}))
	require.NoError(t, modList.Add(mod.MOD{Name: "pinned"}, mod.MODState{Enabled: true, Version: &v1}))
	installed := []mod.InstalledMOD{{MOD: mod.MOD{Name: "pinned"}, Version: v1}}

	saveMODs := []save.MODEntry{
		{Name: "base", Version: mustVersion(t, "2.0.72")},
		{Name: "pinned", Version: mustVersion(t, "2.0.0")},
		{Name: "newcomer", Version: mustVersion(t, "3.0.0")},
	}

	// Without strict: pinned is enabled already, no version sync; newcomer added without version.
	changes := planMODListChanges(modList, saveMODs, installed, false)
	require.Len(t, changes, 1)
	assert.Equal(t, syncAdd, changes[0].action)
	assert.Equal(t, "newcomer", changes[0].mod.Name)
	assert.Nil(t, changes[0].toVersion)

	// With strict: pinned updates to the save version, newcomer records it.
	changes = planMODListChanges(modList, saveMODs, installed, true)
	require.Len(t, changes, 2)
	assert.Equal(t, syncUpdate, changes[0].action)
	assert.Equal(t, "pinned", changes[0].mod.Name)
	assert.Equal(t, "2.0.0", changes[0].toVersion.String())
	assert.Equal(t, "3.0.0", changes[1].toVersion.String())
}
