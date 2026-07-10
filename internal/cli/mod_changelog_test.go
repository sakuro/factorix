package cli

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func changelogFixture(name string) string {
	return filepath.Join("..", "..", "spec", "fixtures", "changelog", name)
}

func TestMODChangelogCheckValid(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "mod", "changelog", "check", "--changelog", changelogFixture("basic.txt"))
	require.NoError(t, err)
	assert.Equal(t, expectedStdout(t, "changelog", "check-valid", "expected_stdout.txt"), out)
}

func TestMODChangelogCheckWrongOrder(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "mod", "changelog", "check", "--changelog", changelogFixture("wrong_order.txt"))
	require.Error(t, err)
	assert.Equal(t, "Changelog validation failed", err.Error())
	assert.Equal(t, expectedStdout(t, "changelog", "check-invalid", "expected_stdout.txt"), out)
}

func TestMODChangelogCheckParseFailure(t *testing.T) {
	s := newSandbox(t)
	path := filepath.Join(s.root, "broken.txt")
	require.NoError(t, os.WriteFile(path, []byte("not a changelog\n"), 0o644))

	out, err := runCLI(t, "mod", "changelog", "check", "--changelog", path)
	require.Error(t, err)
	assert.Contains(t, out, "  - Failed to parse changelog:")
}

func TestMODChangelogCheckReleaseMode(t *testing.T) {
	s := newSandbox(t)
	path := filepath.Join(s.root, "changelog.txt")
	_, err := runCLI(t, "mod", "changelog", "add", "--changelog", path, "--category", "Features", "New", "thing")
	require.NoError(t, err)

	// Unreleased section present and info.json missing.
	out, err := runCLI(t, "mod", "changelog", "check", "--release",
		"--changelog", path, "--info-json", filepath.Join(s.root, "info.json"))
	require.Error(t, err)
	assert.Contains(t, out, "  - Unreleased section is not allowed in release mode\n")
	assert.Contains(t, out, "  - info.json not found: ")

	// Released changelog whose version does not match info.json.
	_, err = runCLI(t, "mod", "changelog", "release", "--changelog", path, "--version", "1.0.0", "--date", "2026-07-10")
	require.NoError(t, err)
	infoPath := filepath.Join(s.root, "info.json")
	info := `{"name": "m", "version": "2.0.0", "title": "m", "author": "a", "factorio_version": "2.0"}`
	require.NoError(t, os.WriteFile(infoPath, []byte(info), 0o644))

	out, err = runCLI(t, "mod", "changelog", "check", "--release", "--changelog", path, "--info-json", infoPath)
	require.Error(t, err)
	assert.Contains(t, out, "  - info.json version (2.0.0) does not match first changelog version (1.0.0)\n")
}

func TestMODChangelogExtractText(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "mod", "changelog", "extract", "--version", "1.1.0", "--changelog", changelogFixture("basic.txt"))
	require.NoError(t, err)
	assert.Equal(t, expectedStdout(t, "changelog", "extract", "expected_stdout.txt"), out)
}

func TestMODChangelogExtractJSON(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "mod", "changelog", "extract", "--version", "1.1.0", "--json", "--changelog", changelogFixture("basic.txt"))
	require.NoError(t, err)
	// Category order follows the file, date is null when absent (as in
	// Ruby's JSON.pretty_generate).
	assert.Equal(t, `{
  "version": "1.1.0",
  "date": null,
  "entries": {
    "Features": [
      "Added new feature A",
      "Added new feature B"
    ],
    "Bugfixes": [
      "Fixed crash on startup"
    ]
  }
}
`, out)
}

func TestMODChangelogExtractVersionNotFound(t *testing.T) {
	newSandbox(t)
	_, err := runCLI(t, "mod", "changelog", "extract", "--version", "9.9.9", "--changelog", changelogFixture("basic.txt"))
	require.Error(t, err)
	assert.Equal(t, "version not found: 9.9.9", err.Error())
}

func TestMODChangelogAddCreatesUnreleased(t *testing.T) {
	s := newSandbox(t)
	path := filepath.Join(s.root, "changelog.txt")

	out, err := runCLI(t, "mod", "changelog", "add", "--changelog", path, "--category", "Features", "Added", "something", "new")
	require.NoError(t, err)
	assert.Equal(t, "✓ Added entry to Unreleased [Features]\n", out)

	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Contains(t, string(data), "Version: Unreleased\n  Features:\n    - Added something new\n")
}

func TestMODChangelogAddToExistingVersion(t *testing.T) {
	s := newSandbox(t)
	path := filepath.Join(s.root, "changelog.txt")
	fixture, err := os.ReadFile(changelogFixture("basic.txt"))
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(path, fixture, 0o644))

	out, err := runCLI(t, "mod", "changelog", "add", "--changelog", path, "--version", "1.0.0", "--category", "Features", "Another", "one")
	require.NoError(t, err)
	assert.Equal(t, "✓ Added entry to 1.0.0 [Features]\n", out)

	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Contains(t, string(data), "    - Initial release\n    - Another one\n")
}

func TestMODChangelogAddDuplicateEntry(t *testing.T) {
	s := newSandbox(t)
	path := filepath.Join(s.root, "changelog.txt")

	_, err := runCLI(t, "mod", "changelog", "add", "--changelog", path, "--category", "Features", "Same")
	require.NoError(t, err)
	_, err = runCLI(t, "mod", "changelog", "add", "--changelog", path, "--category", "Features", "Same")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "duplicate entry: Same")
}

func TestMODChangelogAddRequiresCategory(t *testing.T) {
	newSandbox(t)
	_, err := runCLI(t, "mod", "changelog", "add", "Entry")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "category")
}

func TestMODChangelogRelease(t *testing.T) {
	s := newSandbox(t)
	path := filepath.Join(s.root, "changelog.txt")
	_, err := runCLI(t, "mod", "changelog", "add", "--changelog", path, "--category", "Features", "New", "thing")
	require.NoError(t, err)

	out, err := runCLI(t, "mod", "changelog", "release", "--changelog", path, "--version", "1.2.0", "--date", "2026-07-10")
	require.NoError(t, err)
	assert.Equal(t, "✓ Converted Unreleased to 1.2.0 (2026-07-10)\n", out)

	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Contains(t, string(data), "Version: 1.2.0\nDate: 2026-07-10\n")
}

func TestMODChangelogReleaseVersionFromInfoJSON(t *testing.T) {
	s := newSandbox(t)
	path := filepath.Join(s.root, "changelog.txt")
	infoPath := filepath.Join(s.root, "info.json")
	_, err := runCLI(t, "mod", "changelog", "add", "--changelog", path, "--category", "Features", "New", "thing")
	require.NoError(t, err)
	info := `{"name": "m", "version": "3.4.5", "title": "m", "author": "a", "factorio_version": "2.0"}`
	require.NoError(t, os.WriteFile(infoPath, []byte(info), 0o644))

	out, err := runCLI(t, "mod", "changelog", "release", "--changelog", path, "--info-json", infoPath, "--date", "2026-07-10")
	require.NoError(t, err)
	assert.Equal(t, "✓ Converted Unreleased to 3.4.5 (2026-07-10)\n", out)
}

func TestMODChangelogReleaseWithoutUnreleased(t *testing.T) {
	newSandbox(t)
	_, err := runCLI(t, "mod", "changelog", "release", "--changelog", changelogFixture("basic.txt"), "--version", "9.9.9")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "first section is not Unreleased")
}
