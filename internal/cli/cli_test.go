package cli

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// sandbox builds the directory layout the e2e cases use and points
// FACTORIX_CONFIG at a config selecting it.
type sandbox struct {
	root string
}

func newSandbox(t *testing.T) *sandbox {
	t.Helper()
	root := t.TempDir()
	s := &sandbox{root: root}

	config := "[runtime]\n" +
		"executable_path = " + tomlString(filepath.Join(root, "factorio", "bin", "x64", "factorio")) + "\n" +
		"user_dir = " + tomlString(filepath.Join(root, "factorio")) + "\n" +
		"data_dir = " + tomlString(filepath.Join(root, "factorio", "data")) + "\n"
	configPath := filepath.Join(root, "config.toml")
	require.NoError(t, os.WriteFile(configPath, []byte(config), 0o644))
	t.Setenv("FACTORIX_CONFIG", configPath)

	// Matches the e2e runner (spec/e2e/runner.rb): output comparisons assume
	// plain text, and color depends only on NO_COLOR, never on TTY status.
	t.Setenv("NO_COLOR", "1")

	// Keep the log and cache inside the sandbox.
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "xdg-state"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(root, "xdg-cache"))
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(root, "xdg-config"))

	require.NoError(t, os.MkdirAll(filepath.Join(root, "factorio", "mods"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(root, "factorio", "data"), 0o755))
	return s
}

func tomlString(s string) string {
	return `"` + strings.ReplaceAll(s, `\`, `\\`) + `"`
}

func (s *sandbox) copyFile(t *testing.T, from, to string) {
	t.Helper()
	data, err := os.ReadFile(from)
	require.NoError(t, err)
	dest := filepath.Join(s.root, to)
	require.NoError(t, os.MkdirAll(filepath.Dir(dest), 0o755))
	require.NoError(t, os.WriteFile(dest, data, 0o644))
}

func (s *sandbox) copyDir(t *testing.T, from, to string) {
	t.Helper()
	dest := filepath.Join(s.root, to)
	require.NoError(t, os.MkdirAll(dest, 0o755))
	require.NoError(t, os.CopyFS(dest, os.DirFS(from)))
}

// writeInstalledMOD creates a directory-form installed MOD under
// factorio/mods/<name> with the given version and dependency strings.
func (s *sandbox) writeInstalledMOD(t *testing.T, name, version string, dependencies []string) {
	t.Helper()
	depsJSON, err := json.Marshal(dependencies)
	require.NoError(t, err)
	info := fmt.Sprintf(`{"name": %q, "version": %q, "title": %q, "author": "test", "dependencies": %s}`,
		name, version, name, depsJSON)
	dir := filepath.Join(s.root, "factorio", "mods", name)
	require.NoError(t, os.MkdirAll(dir, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "info.json"), []byte(info), 0o644))
}

// modListEntry is one entry to write into mod-list.json via writeMODList.
type modListEntry struct {
	name    string
	enabled bool
	version string // "" omits the field, matching a MOD never explicitly versioned
}

func (s *sandbox) writeMODList(t *testing.T, entries ...modListEntry) {
	t.Helper()
	type entry struct {
		Name    string `json:"name"`
		Enabled bool   `json:"enabled"`
		Version string `json:"version,omitempty"`
	}
	doc := struct {
		Mods []entry `json:"mods"`
	}{}
	for _, e := range entries {
		doc.Mods = append(doc.Mods, entry{Name: e.name, Enabled: e.enabled, Version: e.version})
	}
	data, err := json.MarshalIndent(doc, "", "  ")
	require.NoError(t, err)
	path := filepath.Join(s.root, "factorio", "mods", "mod-list.json")
	require.NoError(t, os.WriteFile(path, data, 0o644))
}

// readMODList reads back mod-list.json as a name -> enabled map for
// assertions.
func (s *sandbox) readMODList(t *testing.T) map[string]bool {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(s.root, "factorio", "mods", "mod-list.json"))
	require.NoError(t, err)
	var doc struct {
		Mods []struct {
			Name    string `json:"name"`
			Enabled bool   `json:"enabled"`
		} `json:"mods"`
	}
	require.NoError(t, json.Unmarshal(data, &doc))
	result := map[string]bool{}
	for _, m := range doc.Mods {
		result[m.Name] = m.Enabled
	}
	return result
}

func e2eFile(elems ...string) string {
	return filepath.Join(append([]string{"..", "..", "e2e", "cases"}, elems...)...)
}

func expectedStdout(t *testing.T, elems ...string) string {
	t.Helper()
	data, err := os.ReadFile(e2eFile(elems...))
	require.NoError(t, err)
	return string(data)
}

// setupMODListSandbox mirrors the e2e mod-list/mod-check "valid" layout.
func setupMODListSandbox(t *testing.T) *sandbox {
	s := newSandbox(t)
	s.copyFile(t, e2eFile("mod-list", "table", "files", "mod-list.json"), "factorio/mods/mod-list.json")
	s.copyFile(t, e2eFile("mod-list", "table", "files", "base-info.json"), "factorio/data/base/info.json")
	s.copyDir(t, filepath.Join("..", "..", "spec", "fixtures", "mods", "upload-test"), "factorio/mods/upload-test")
	return s
}

// runCLI executes the command tree the same way main.go does, including
// the reportError call on failure, so captured stdout matches what a real
// invocation would print (and thus the e2e expected_stdout.txt fixtures).
func runCLI(t *testing.T, args ...string) (string, error) {
	t.Helper()
	return runCLIWithStdin(t, "", args...)
}

// runCLIWithStdin is runCLI with an explicit stdin, for commands that
// prompt for confirmation.
func runCLIWithStdin(t *testing.T, stdin string, args ...string) (string, error) {
	t.Helper()
	root, reportError := NewRootCommand()
	var out bytes.Buffer
	root.SetOut(&out)
	root.SetErr(&out)
	root.SetIn(strings.NewReader(stdin))
	root.SetArgs(args)
	err := root.Execute()
	if err != nil {
		reportError(err)
	}
	return out.String(), err
}

func TestVersionCommand(t *testing.T) {
	out, err := runCLI(t, "version")
	require.NoError(t, err)
	assert.Equal(t, "dev\n", out)
}

// TestVersionCommandNeverBuildsApp guards against PersistentPostRun's
// Close() forcing application construction (config load, log file
// creation) for a command that never calls c.App() itself.
func TestVersionCommandNeverBuildsApp(t *testing.T) {
	s := newSandbox(t)

	_, err := runCLI(t, "version")
	require.NoError(t, err)

	logPath := filepath.Join(s.root, "xdg-state", "factorix", "factorix.log")
	_, statErr := os.Stat(logPath)
	assert.ErrorIs(t, statErr, os.ErrNotExist, "version must not trigger app construction")
}

func TestPathCommand(t *testing.T) {
	s := newSandbox(t)
	out, err := runCLI(t, "path")
	require.NoError(t, err)

	lines := strings.Split(strings.TrimRight(out, "\n"), "\n")
	require.Len(t, lines, 15)
	assert.Equal(t, "executable_path       "+filepath.Join(s.root, "factorio", "bin", "x64", "factorio"), lines[0])
	assert.Equal(t, "data_dir              "+filepath.Join(s.root, "factorio", "data"), lines[1])
	assert.Equal(t, "user_dir              "+filepath.Join(s.root, "factorio"), lines[2])
	assert.Equal(t, "mod_dir               "+filepath.Join(s.root, "factorio", "mods"), lines[3])
	assert.Equal(t, "factorix_log_path     "+filepath.Join(s.root, "xdg-state", "factorix", "factorix.log"), lines[14])
}

func TestPathCommandJSON(t *testing.T) {
	s := newSandbox(t)
	out, err := runCLI(t, "path", "--json")
	require.NoError(t, err)

	assert.True(t, strings.HasPrefix(out, "{\n  \"executable_path\":"))
	assert.Contains(t, out, `"mod_list_path": `)
	assert.Contains(t, out, filepath.Join(s.root, "factorio", "mods"))
}

func TestMODListTable(t *testing.T) {
	setupMODListSandbox(t)
	out, err := runCLI(t, "mod", "list")
	require.NoError(t, err)
	assert.Equal(t, expectedStdout(t, "mod-list", "table", "expected_stdout.txt"), out)
}

func TestMODListJSON(t *testing.T) {
	setupMODListSandbox(t)
	out, err := runCLI(t, "mod", "list", "--json")
	require.NoError(t, err)
	assert.Equal(t, expectedStdout(t, "mod-list", "json", "expected_stdout.txt"), out)
}

func TestMODListConflictingFilters(t *testing.T) {
	setupMODListSandbox(t)
	_, err := runCLI(t, "mod", "list", "--enabled", "--disabled")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "--enabled, --disabled")
}

func TestMODCheckValid(t *testing.T) {
	setupMODListSandbox(t)
	out, err := runCLI(t, "mod", "check")
	require.NoError(t, err)
	assert.Equal(t, expectedStdout(t, "mod-check", "valid", "expected_stdout.txt"), out)
}

func TestMODCheckMissingDependency(t *testing.T) {
	s := newSandbox(t)
	base := e2eFile("mod-check", "missing-dependency", "files")
	s.copyFile(t, filepath.Join(base, "mod-list.json"), "factorio/mods/mod-list.json")
	s.copyFile(t, filepath.Join(base, "base-info.json"), "factorio/data/base/info.json")
	s.copyFile(t, filepath.Join(base, "needs-lib-info.json"), "factorio/mods/needs-lib/info.json")

	out, err := runCLI(t, "mod", "check")
	require.ErrorIs(t, err, errValidationFailed)
	assert.Equal(t, expectedStdout(t, "mod-check", "missing-dependency", "expected_stdout.txt"), out)
}

func TestMODSettingsDumpAndRestore(t *testing.T) {
	s := newSandbox(t)
	s.copyFile(t, e2eFile("mod-settings", "dump", "files", "mod-settings.dat"), "cwd/mod-settings.dat")
	settingsPath := filepath.Join(s.root, "cwd", "mod-settings.dat")

	out, err := runCLI(t, "mod", "settings", "dump", settingsPath)
	require.NoError(t, err)
	assert.Equal(t, expectedStdout(t, "mod-settings", "dump", "expected_stdout.txt"), out)

	// Restore the dump into a new file and dump it again: same JSON.
	restored := filepath.Join(s.root, "cwd", "restored.dat")
	inputPath := filepath.Join(s.root, "cwd", "settings.json")
	require.NoError(t, os.WriteFile(inputPath, []byte(out), 0o644))

	_, err = runCLI(t, "mod", "settings", "restore", restored, "-i", inputPath)
	require.NoError(t, err)

	out2, err := runCLI(t, "mod", "settings", "dump", restored)
	require.NoError(t, err)
	assert.Equal(t, out, out2)
}

func TestMODSettingsRestoreBacksUpExisting(t *testing.T) {
	s := newSandbox(t)
	s.copyFile(t, e2eFile("mod-settings", "dump", "files", "mod-settings.dat"), "cwd/mod-settings.dat")
	settingsPath := filepath.Join(s.root, "cwd", "mod-settings.dat")

	dump, err := runCLI(t, "mod", "settings", "dump", settingsPath)
	require.NoError(t, err)
	inputPath := filepath.Join(s.root, "cwd", "settings.json")
	require.NoError(t, os.WriteFile(inputPath, []byte(dump), 0o644))

	_, err = runCLI(t, "mod", "settings", "restore", settingsPath, "-i", inputPath)
	require.NoError(t, err)
	assert.FileExists(t, settingsPath+".bak")
}

func TestMODSettingsRestoreRequiresGameStopped(t *testing.T) {
	s := newSandbox(t)
	require.NoError(t, os.WriteFile(filepath.Join(s.root, "factorio", ".lock"), nil, 0o644))

	_, err := runCLI(t, "mod", "settings", "restore", filepath.Join(s.root, "out.dat"), "-i", "/dev/null")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "running")
}

func TestQuietSuppressesDecoratedOutput(t *testing.T) {
	setupMODListSandbox(t)
	out, err := runCLI(t, "mod", "list", "-q")
	require.NoError(t, err)
	assert.Contains(t, out, "NAME")
	assert.NotContains(t, out, "Summary")
}
