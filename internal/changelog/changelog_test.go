package changelog

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
)

func fixture(t *testing.T, name string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("..", "..", "testdata", "changelog", name))
	require.NoError(t, err)
	return string(data)
}

func versionPtr(major, minor, patch uint16) *mod.MODVersion {
	v, err := mod.NewMODVersion(major, minor, patch)
	if err != nil {
		panic(err)
	}
	return &v
}

func TestParseBasic(t *testing.T) {
	c, err := Parse(fixture(t, "basic.txt"))
	require.NoError(t, err)

	sections := c.Sections()
	require.Len(t, sections, 2)
	assert.Equal(t, "1.1.0", sections[0].VersionLabel())
	assert.Equal(t, "1.0.0", sections[1].VersionLabel())

	require.Len(t, sections[0].Categories, 2)
	assert.Equal(t, "Features", sections[0].Categories[0].Name)
	assert.Equal(t, []string{"Added new feature A", "Added new feature B"}, sections[0].Categories[0].Entries)
	assert.Equal(t, "Bugfixes", sections[0].Categories[1].Name)
}

func TestParseWithDateAndUnreleased(t *testing.T) {
	c, err := Parse(fixture(t, "with_date.txt"))
	require.NoError(t, err)
	assert.Equal(t, "2025-01-15", c.Sections()[0].Date)

	c, err = Parse(fixture(t, "with_unreleased.txt"))
	require.NoError(t, err)
	assert.Nil(t, c.Sections()[0].Version)
	assert.Equal(t, Unreleased, c.Sections()[0].VersionLabel())

	unreleased, ok := c.FindSection(nil)
	require.True(t, ok)
	assert.Equal(t, "Features", unreleased.Categories[0].Name)
}

func TestParseMultilineEntry(t *testing.T) {
	c, err := Parse(fixture(t, "multiline_entry.txt"))
	require.NoError(t, err)

	entries := c.Sections()[0].Categories[0].Entries
	require.Len(t, entries, 2)
	assert.Equal(t, "Added a complex feature that spans\nmultiple lines of description", entries[0])
	assert.Equal(t, "Simple entry", entries[1])
}

func TestRoundTrip(t *testing.T) {
	for _, name := range []string{"basic.txt", "with_date.txt", "with_unreleased.txt", "multiline_entry.txt", "unreleased_not_first.txt", "wrong_order.txt"} {
		t.Run(name, func(t *testing.T) {
			text := fixture(t, name)
			c, err := Parse(text)
			require.NoError(t, err)
			assert.Equal(t, text, c.String())
		})
	}
}

func TestParseErrors(t *testing.T) {
	inputs := map[string]string{
		"empty":             "",
		"no separator":      "Version: 1.0.0\n",
		"short separator":   "---\nVersion: 1.0.0\n",
		"missing version":   Separator + "\nDate: 2024-01-01\n",
		"bad version":       Separator + "\nVersion: not-a-version\n",
		"category no entry": Separator + "\nVersion: 1.0.0\n  Features:\n",
	}
	for name, input := range inputs {
		t.Run(name, func(t *testing.T) {
			_, err := Parse(input)
			require.ErrorIs(t, err, ErrParse, "input: %q", input)
		})
	}
}

func TestAddEntry(t *testing.T) {
	c := New()

	// Adding to a missing section creates it at the top.
	require.NoError(t, c.AddEntry(nil, "Features", "New thing"))
	require.NoError(t, c.AddEntry(nil, "Features", "Another thing"))
	require.NoError(t, c.AddEntry(nil, "Bugfixes", "Fixed thing"))

	unreleased, ok := c.FindSection(nil)
	require.True(t, ok)
	assert.Equal(t, []string{"New thing", "Another thing"}, unreleased.Categories[0].Entries)

	err := c.AddEntry(nil, "Features", "New thing")
	require.ErrorIs(t, err, ErrInvalidArgument) // duplicate

	err = c.AddEntry(nil, "Features", "   ")
	require.ErrorIs(t, err, ErrInvalidArgument) // blank
}

func TestReleaseSection(t *testing.T) {
	c, err := Parse(fixture(t, "with_unreleased.txt"))
	require.NoError(t, err)

	require.NoError(t, c.ReleaseSection(*versionPtr(1, 1, 0), "2025-02-01"))
	assert.Equal(t, "1.1.0", c.Sections()[0].VersionLabel())
	assert.Equal(t, "2025-02-01", c.Sections()[0].Date)

	// No Unreleased section anymore.
	err = c.ReleaseSection(*versionPtr(1, 2, 0), "2025-03-01")
	require.ErrorIs(t, err, ErrInvalidOperation)
}

func TestReleaseSectionExistingVersion(t *testing.T) {
	c, err := Parse(fixture(t, "with_unreleased.txt"))
	require.NoError(t, err)

	err = c.ReleaseSection(*versionPtr(1, 0, 0), "2025-02-01")
	require.ErrorIs(t, err, ErrInvalidOperation)
}

func TestLoadMissingFile(t *testing.T) {
	c, err := Load(filepath.Join(t.TempDir(), "changelog.txt"))
	require.NoError(t, err)
	assert.Empty(t, c.Sections())
}

func TestSaveAndLoad(t *testing.T) {
	c := New()
	require.NoError(t, c.AddEntry(nil, "Features", "First"))

	path := filepath.Join(t.TempDir(), "changelog.txt")
	require.NoError(t, c.Save(path))

	loaded, err := Load(path)
	require.NoError(t, err)
	assert.Equal(t, c.String(), loaded.String())
}
