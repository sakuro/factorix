package cli

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

func TestMODInstallRequiresGameStopped(t *testing.T) {
	s := baseSandbox(t)
	require.NoError(t, os.WriteFile(filepath.Join(s.root, "factorio", ".lock"), nil, 0o644))

	_, err := runCLI(t, "mod", "install", "some-mod", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "running")
}

// A missing MOD directory (which also means a missing mod-list.json, since
// the file lives inside it) must fail locally, before any Portal request.
func TestMODInstallFailsWithoutMODDir(t *testing.T) {
	s := baseSandbox(t)
	require.NoError(t, os.RemoveAll(filepath.Join(s.root, "factorio", "mods")))

	_, err := runCLI(t, "mod", "install", "some-mod", "-y")
	require.Error(t, err)
	require.ErrorIs(t, err, os.ErrNotExist)
}

func TestSplitInstallTargets(t *testing.T) {
	targets := []installTarget{
		{MOD: mod.MOD{Name: "a"}, Operation: dependency.OpInstall},
		{MOD: mod.MOD{Name: "b"}, Operation: dependency.OpEnable},
		{MOD: mod.MOD{Name: "c"}, Operation: dependency.OpInstall},
	}
	installs, enables := splitInstallTargets(targets)
	require.Len(t, installs, 2)
	require.Len(t, enables, 1)
	assert.Equal(t, "b", enables[0].MOD.Name)
}

func TestMODUpdateRejectsBaseAndExpansion(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})

	_, err := runCLI(t, "mod", "update", "base", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Cannot update base MOD")

	_, err = runCLI(t, "mod", "update", "quality", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Cannot update expansion MOD: quality")
}

func TestMODUpdateNothingInstalled(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})

	// Only base is installed; with no names given there is nothing to check.
	out, err := runCLI(t, "mod", "update", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "No MOD(s) to update")
}

func TestMODUpdateRequiresGameStopped(t *testing.T) {
	s := baseSandbox(t)
	require.NoError(t, os.WriteFile(filepath.Join(s.root, "factorio", ".lock"), nil, 0o644))

	_, err := runCLI(t, "mod", "update", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "running")
}

func TestUpdateTargetMODs(t *testing.T) {
	installed := []mod.InstalledMOD{
		{MOD: mod.MOD{Name: "base"}, Version: mod.MODVersion{Major: 2}},
		{MOD: mod.MOD{Name: "space-age"}, Version: mod.MODVersion{Major: 2}},
		{MOD: mod.MOD{Name: "some-mod"}, Version: mod.MODVersion{Major: 1}},
		{MOD: mod.MOD{Name: "some-mod"}, Version: mod.MODVersion{Major: 2}}, // duplicate version entry
	}

	targets, err := updateTargetMODs(nil, installed)
	require.NoError(t, err)
	assert.Equal(t, []mod.MOD{{Name: "some-mod"}}, targets)

	targets, err = updateTargetMODs([]string{"another-mod"}, installed)
	require.NoError(t, err)
	assert.Equal(t, []mod.MOD{{Name: "another-mod"}}, targets)
}

func TestNewestInstalledVersion(t *testing.T) {
	installed := []mod.InstalledMOD{
		{MOD: mod.MOD{Name: "m"}, Version: mod.MODVersion{Major: 1}},
		{MOD: mod.MOD{Name: "m"}, Version: mod.MODVersion{Major: 3}},
		{MOD: mod.MOD{Name: "m"}, Version: mod.MODVersion{Major: 2}},
	}
	version, found := newestInstalledVersion(installed, mod.MOD{Name: "m"})
	require.True(t, found)
	assert.Equal(t, mod.MODVersion{Major: 3}, version)

	_, found = newestInstalledVersion(installed, mod.MOD{Name: "absent"})
	assert.False(t, found)
}
