package cli

import (
	"archive/zip"
	"io/fs"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// zipDirectory packs srcDir's files into zipPath under the topLevel
// directory, the layout InstalledMODFromZIP expects.
func zipDirectory(t *testing.T, srcDir, topLevel, zipPath string) error {
	t.Helper()
	f, err := os.Create(zipPath)
	if err != nil {
		return err
	}
	defer f.Close()

	zw := zip.NewWriter(f)
	err = filepath.WalkDir(srcDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		rel, err := filepath.Rel(srcDir, path)
		if err != nil {
			return err
		}
		w, err := zw.Create(topLevel + "/" + filepath.ToSlash(rel))
		if err != nil {
			return err
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		_, err = w.Write(data)
		return err
	})
	if err != nil {
		return err
	}
	return zw.Close()
}

// writeInstalledMODZip creates a ZIP-form installed MOD, so uninstall can
// exercise both removal paths (os.Remove for ZIPs, os.RemoveAll for dirs).
func (s *sandbox) writeInstalledMODZip(t *testing.T, name, version string) {
	t.Helper()
	src := t.TempDir()
	modDir := filepath.Join(src, name)
	require.NoError(t, os.MkdirAll(modDir, 0o755))
	info := `{"name": "` + name + `", "version": "` + version + `", "title": "` + name + `", "author": "test"}`
	require.NoError(t, os.WriteFile(filepath.Join(modDir, "info.json"), []byte(info), 0o644))

	zipPath := filepath.Join(s.root, "factorio", "mods", name+"_"+version+".zip")
	require.NoError(t, zipDirectory(t, modDir, name+"_"+version, zipPath))
}

func TestMODUninstallSimple(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "doomed", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "doomed", enabled: true})

	out, err := runCLI(t, "mod", "uninstall", "doomed", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "Planning to uninstall 1 MOD(s):")
	assert.Contains(t, out, "  - doomed")
	assert.Contains(t, out, "Removed doomed from mod-list.json")
	assert.Contains(t, out, "Uninstalled 1 MOD(s)")

	assert.NoDirExists(t, filepath.Join(s.root, "factorio", "mods", "doomed"))
	_, ok := s.readMODList(t)["doomed"]
	assert.False(t, ok, "doomed must be gone from mod-list.json")
	assert.FileExists(t, filepath.Join(s.root, "factorio", "mods", "mod-list.json.bak"))
}

func TestMODUninstallZIPForm(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMODZip(t, "zipped", "1.0.0")
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "zipped", enabled: true})

	_, err := runCLI(t, "mod", "uninstall", "zipped", "-y")
	require.NoError(t, err)
	assert.NoFileExists(t, filepath.Join(s.root, "factorio", "mods", "zipped_1.0.0.zip"))
}

func TestMODUninstallSpecificVersionKeepsOthers(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMODZip(t, "multi", "1.0.0")
	s.writeInstalledMODZip(t, "multi", "2.0.0")
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "multi", enabled: true})

	out, err := runCLI(t, "mod", "uninstall", "multi@1.0.0", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "  - multi@1.0.0")

	assert.NoFileExists(t, filepath.Join(s.root, "factorio", "mods", "multi_1.0.0.zip"))
	assert.FileExists(t, filepath.Join(s.root, "factorio", "mods", "multi_2.0.0.zip"))
	// A version remains installed, so the list entry stays.
	assert.NotContains(t, out, "Removed multi from mod-list.json")
	_, ok := s.readMODList(t)["multi"]
	assert.True(t, ok)
}

func TestMODUninstallRejectsBaseAndExpansion(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})

	_, err := runCLI(t, "mod", "uninstall", "base", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Cannot uninstall base MOD")

	_, err = runCLI(t, "mod", "uninstall", "space-age", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Cannot uninstall expansion MOD: space-age")
}

func TestMODUninstallNotInstalledWarns(t *testing.T) {
	s := baseSandbox(t)
	s.writeMODList(t, modListEntry{name: "base", enabled: true})

	out, err := runCLI(t, "mod", "uninstall", "ghost", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "⚠︎ MOD not installed: ghost")
	assert.Contains(t, out, "No MOD(s) to uninstall")
}

func TestMODUninstallVersionNotInstalledWarns(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "some-mod", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "some-mod", enabled: true})

	out, err := runCLI(t, "mod", "uninstall", "some-mod@9.9.9", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "⚠︎ MOD version not installed: some-mod@9.9.9")
	assert.Contains(t, out, "No MOD(s) to uninstall")
}

func TestMODUninstallBlockedByDependents(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"lib"})
	s.writeInstalledMOD(t, "lib", "1.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "app", enabled: true},
		modListEntry{name: "lib", enabled: true},
	)

	_, err := runCLI(t, "mod", "uninstall", "lib", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Cannot uninstall lib: the following enabled MOD(s) depend on it: app")

	assert.DirExists(t, filepath.Join(s.root, "factorio", "mods", "lib"))
}

func TestMODUninstallVersionedKeepSatisfiesDependent(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"lib >= 2.0"})
	s.writeInstalledMODZip(t, "lib", "1.0.0")
	s.writeInstalledMODZip(t, "lib", "2.0.0")
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "app", enabled: true},
		modListEntry{name: "lib", enabled: true},
	)

	// Removing 1.0.0 leaves 2.0.0, which still satisfies app's requirement.
	_, err := runCLI(t, "mod", "uninstall", "lib@1.0.0", "-y")
	require.NoError(t, err)
	assert.NoFileExists(t, filepath.Join(s.root, "factorio", "mods", "lib_1.0.0.zip"))
	assert.FileExists(t, filepath.Join(s.root, "factorio", "mods", "lib_2.0.0.zip"))

	// Removing 2.0.0 would leave only 1.0.0, which does not satisfy >= 2.0.
	_, err = runCLI(t, "mod", "uninstall", "lib@2.0.0", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "the following enabled MOD(s) depend on it: app")
}

func TestMODUninstallAll(t *testing.T) {
	s := baseSandbox(t)
	spaceAgeInfo := `{"name": "space-age", "version": "1.1.110", "title": "Space Age", "author": "Wube"}`
	spaceAgeDir := filepath.Join(s.root, "factorio", "data", "space-age")
	require.NoError(t, os.MkdirAll(spaceAgeDir, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(spaceAgeDir, "info.json"), []byte(spaceAgeInfo), 0o644))
	s.writeInstalledMOD(t, "mod-a", "1.0.0", nil)
	s.writeInstalledMOD(t, "mod-b", "1.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "space-age", enabled: true},
		modListEntry{name: "mod-a", enabled: true},
		modListEntry{name: "mod-b", enabled: false},
	)

	out, err := runCLI(t, "mod", "uninstall", "--all", "-y")
	require.NoError(t, err)
	assert.Contains(t, out, "Planning to uninstall 2 MOD(s):")
	assert.Contains(t, out, "Expansion MOD(s) to be disabled:")
	assert.Contains(t, out, "Disabled expansion MOD: space-age")
	assert.Contains(t, out, "Uninstalled 2 MOD(s)")

	states := s.readMODList(t)
	assert.True(t, states["base"], "base stays enabled")
	assert.False(t, states["space-age"], "expansion disabled, not removed")
	_, hasA := states["mod-a"]
	assert.False(t, hasA)
}

func TestMODUninstallArgumentValidation(t *testing.T) {
	baseSandbox(t)

	_, err := runCLI(t, "mod", "uninstall")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Must specify MOD names or use --all option")

	_, err = runCLI(t, "mod", "uninstall", "some-mod", "--all")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Cannot specify MOD names with --all option")

	// @latest is not meaningful for uninstall; the version must be exact.
	_, err = runCLI(t, "mod", "uninstall", "some-mod@latest")
	require.Error(t, err)
}

func TestMODUninstallPromptDecline(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "doomed", "1.0.0", nil)
	s.writeMODList(t, modListEntry{name: "base", enabled: true}, modListEntry{name: "doomed", enabled: true})

	_, err := runCLIWithStdin(t, "n\n", "mod", "uninstall", "doomed")
	require.NoError(t, err)
	assert.DirExists(t, filepath.Join(s.root, "factorio", "mods", "doomed"))
}

func TestMODUninstallRequiresGameStopped(t *testing.T) {
	s := baseSandbox(t)
	require.NoError(t, os.WriteFile(filepath.Join(s.root, "factorio", ".lock"), nil, 0o644))

	_, err := runCLI(t, "mod", "uninstall", "anything", "-y")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "running")
}
