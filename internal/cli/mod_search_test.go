package cli

import (
	"bytes"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/mod"
)

func sampleSearchMODs() []api.MODInfo {
	v, _ := mod.ParseMODVersion("1.2.0")
	return []api.MODInfo{
		{
			Name: "some-mod", Title: "Some MOD", Owner: "alice", Category: "content",
			LatestRelease: &api.Release{Version: v},
		},
		{Name: "no-release-mod", Title: "No Release", Owner: "bob", Category: "utilities"},
	}
}

func TestHideDeprecatedParam(t *testing.T) {
	require.NotNil(t, hideDeprecatedParam(true, false))
	assert.True(t, *hideDeprecatedParam(true, false))
	assert.Nil(t, hideDeprecatedParam(false, false))
	assert.Nil(t, hideDeprecatedParam(true, true)) // --no-hide-deprecated wins over the default
}

func TestMODSearchRejectsConflictingHideDeprecatedFlags(t *testing.T) {
	_, err := runCLI(t, "mod", "search", "--hide-deprecated", "--no-hide-deprecated", "query")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "hide-deprecated")
	assert.Contains(t, err.Error(), "no-hide-deprecated")
}

func TestOutputSearchTable(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	var buf bytes.Buffer
	p := &printer{out: &buf}

	require.NoError(t, outputSearchTable(p, sampleSearchMODs()))

	out := buf.String()
	assert.Contains(t, out, "NAME")
	assert.Contains(t, out, "CATEGORY")
	assert.Contains(t, out, "some-mod")
	assert.Contains(t, out, "Content") // display name, not the raw "content" value
	assert.Contains(t, out, "Utilities")
	assert.Contains(t, out, "1.2.0")
	assert.Contains(t, out, "2 MOD(s) found")
}

func TestOutputSearchTableEmpty(t *testing.T) {
	var buf bytes.Buffer
	p := &printer{out: &buf}
	require.NoError(t, outputSearchTable(p, nil))
	assert.Contains(t, buf.String(), "No MOD(s) found")
}

func TestOutputSearchTableUnknownCategory(t *testing.T) {
	var buf bytes.Buffer
	p := &printer{out: &buf}
	mods := []api.MODInfo{{Name: "some-mod", Category: "not-a-real-category"}}

	err := outputSearchTable(p, mods)
	require.ErrorIs(t, err, api.ErrInvalidResponse)
}

func TestOutputSearchJSON(t *testing.T) {
	var buf bytes.Buffer
	p := &printer{out: &buf}
	require.NoError(t, outputSearchJSON(p, sampleSearchMODs()))

	out := buf.String()
	assert.Contains(t, out, `"category": "content"`) // raw value, not display name
	assert.Contains(t, out, `"thumbnail": null`)
	assert.Contains(t, out, `"latest_release": null`) // no-release-mod has none
}
