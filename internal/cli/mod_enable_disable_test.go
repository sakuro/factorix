package cli

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// baseSandbox sets up base (always enabled) plus the given MODs, listed in
// mod-list.json in the given enabled state with no pinned version.
func baseSandbox(t *testing.T) *sandbox {
	t.Helper()
	s := newSandbox(t)
	s.copyFile(t, e2eFile("mod-list", "table", "files", "base-info.json"), "factorio/data/base/info.json")
	return s
}

func TestMODEnableSimple(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"lib"})
	s.writeInstalledMOD(t, "lib", "1.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "app", enabled: false},
		modListEntry{name: "lib", enabled: false},
	)

	out, err := runCLI(t, "mod", "enable", "app", "-y")
	require.NoError(t, err)
	assert.Equal(t, "ℹ Planning to enable 2 MOD(s):\n"+
		"  - app\n"+
		"  - lib\n"+
		"✓ Enabled app\n"+
		"✓ Enabled lib\n"+
		"✓ Enabled 2 MOD(s)\n"+
		"✓ Saved mod-list.json\n", out)

	states := s.readMODList(t)
	assert.True(t, states["app"])
	assert.True(t, states["lib"])
}

func TestMODEnablePullsInInstalledRecommendedDep(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"+ lib"})
	s.writeInstalledMOD(t, "lib", "1.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "app", enabled: false},
		modListEntry{name: "lib", enabled: false},
	)

	out, err := runCLI(t, "mod", "enable", "app", "-y")
	require.NoError(t, err)
	assert.Equal(t, "ℹ Planning to enable 2 MOD(s):\n"+
		"  - app\n"+
		"  - lib\n"+
		"✓ Enabled app\n"+
		"✓ Enabled lib\n"+
		"✓ Enabled 2 MOD(s)\n"+
		"✓ Saved mod-list.json\n", out)

	states := s.readMODList(t)
	assert.True(t, states["app"])
	assert.True(t, states["lib"])
}

func TestMODEnableSkipsUninstalledRecommendedDep(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"+ ghost"})
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "app", enabled: false})

	out, err := runCLI(t, "mod", "enable", "app", "-y")
	require.NoError(t, err)
	assert.Equal(t, "ℹ Planning to enable 1 MOD(s):\n"+
		"  - app\n"+
		"✓ Enabled app\n"+
		"✓ Enabled 1 MOD(s)\n"+
		"✓ Saved mod-list.json\n", out)
}

func TestMODEnableCustomBackupExtension(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "app", enabled: false})

	_, err := runCLI(t, "mod", "enable", "app", "-y", "--backup-extension", ".orig")
	require.NoError(t, err)
	assert.FileExists(t, filepath.Join(s.root, "factorio", "mods", "mod-list.json.orig"))
	assert.NoFileExists(t, filepath.Join(s.root, "factorio", "mods", "mod-list.json.bak"))
}

func TestMODEnableAlreadyEnabled(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "app", enabled: true})

	out, err := runCLI(t, "mod", "enable", "app")
	require.NoError(t, err)
	assert.Equal(t, "ℹ All specified MOD(s) are already enabled\n", out)
}

func TestMODEnableNotInstalled(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})

	_, err := runCLI(t, "mod", "enable", "ghost")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "MOD 'ghost' is not installed")
}

func TestMODEnableMissingDependency(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"missing-lib"})
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "app", enabled: false})

	_, err := runCLI(t, "mod", "enable", "app", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "MOD 'app' requires 'missing-lib' which is not installed")

	// Nothing was saved: the plan failed before any changes.
	assert.False(t, s.readMODList(t)["app"])
}

func TestMODEnableConflict(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"! rival"})
	s.writeInstalledMOD(t, "rival", "1.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "app", enabled: false},
		modListEntry{name: "rival", enabled: true},
	)

	_, err := runCLI(t, "mod", "enable", "app", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "conflicts with rival which is currently enabled")
}

func TestMODEnablePromptAccept(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "app", enabled: false})

	out, err := runCLIWithStdin(t, "y\n", "mod", "enable", "app")
	require.NoError(t, err)
	assert.Contains(t, out, "Do you want to enable these MOD(s)? [y/N] ")
	assert.True(t, s.readMODList(t)["app"])
}

func TestMODEnablePromptDecline(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "app", enabled: false})

	_, err := runCLIWithStdin(t, "n\n", "mod", "enable", "app")
	require.NoError(t, err)
	assert.False(t, s.readMODList(t)["app"])
}

func TestMODEnableQuietRequiresYes(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "app", enabled: false})

	_, err := runCLI(t, "mod", "enable", "app", "-q")
	require.ErrorIs(t, err, errConfirmRequiresYes)
	assert.False(t, s.readMODList(t)["app"])
}

func TestMODDisableSimple(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"lib"})
	s.writeInstalledMOD(t, "lib", "1.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "app", enabled: true},
		modListEntry{name: "lib", enabled: true},
	)

	// Disabling the dependency pulls in the dependent.
	out, err := runCLI(t, "mod", "disable", "lib", "-y")
	require.NoError(t, err)
	assert.Equal(t, "ℹ Planning to disable 2 MOD(s):\n"+
		"  - lib\n"+
		"  - app\n"+
		"✓ Disabled lib\n"+
		"✓ Disabled app\n"+
		"✓ Disabled 2 MOD(s)\n"+
		"✓ Saved mod-list.json\n", out)

	states := s.readMODList(t)
	assert.False(t, states["lib"])
	assert.False(t, states["app"])
}

func TestMODDisableAll(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "app", enabled: true})

	out, err := runCLI(t, "mod", "disable", "--all", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "Disabled app")
	assert.True(t, s.readMODList(t)["base"], "base must stay enabled")
	assert.False(t, s.readMODList(t)["app"])
}

func TestMODDisableBaseRejected(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})

	_, err := runCLI(t, "mod", "disable", "base", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "cannot disable the base MOD")
}

func TestMODDisableNotInstalledWarns(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})

	out, err := runCLI(t, "mod", "disable", "ghost", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "⚠︎ MOD not installed, skipping: ghost")
	assert.Contains(t, out, "All specified MOD(s) are already disabled")
}

func TestMODDisableArgumentValidation(t *testing.T) {
	baseSandbox(t)

	_, err := runCLI(t, "mod", "disable")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Must specify MOD names or use --all option")

	_, err = runCLI(t, "mod", "disable", "app", "--all")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Cannot specify MOD names with --all option")
}

func TestMODEnableRequiresGameStopped(t *testing.T) {
	s := baseSandbox(t)
	require.NoError(t, os.WriteFile(filepath.Join(s.root, "factorio", ".lock"), nil, 0o644))

	_, err := runCLI(t, "mod", "enable", "app")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "running")
}
