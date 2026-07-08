package cli

import (
	"bytes"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/mod"
)

func sampleShowMODInfo() *api.MODInfo {
	v, _ := mod.ParseMODVersion("2.0.0")
	return &api.MODInfo{
		Name: "some-mod", Title: "Some MOD", Summary: "A test MOD", Owner: "alice",
		Category: "content", DownloadsCount: 42,
		License:   &api.License{Title: "MIT License"},
		SourceURL: "https://example.com/src", Homepage: "https://example.com",
		LatestRelease: &api.Release{
			Version: v,
			InfoJSON: api.ReleaseInfoJSON{
				FactorioVersion: "2.0",
				Dependencies:    []string{"base", "lib >= 1.0", "? optional-lib", "! bad-mod", "~ neutral-mod"},
			},
		},
	}
}

func TestClassifyDependencies(t *testing.T) {
	required, optional, incompatible := classifyDependencies([]string{
		"base", "lib >= 1.0", "? optional-lib", "(?) hidden-lib", "! bad-mod", "~ neutral-mod",
	})
	assert.Equal(t, []string{"base", "lib >= 1.0"}, required)
	assert.Equal(t, []string{"optional-lib", "hidden-lib"}, optional)
	assert.Equal(t, []string{"bad-mod"}, incompatible)
}

func TestFormatLocalStatus(t *testing.T) {
	assert.Equal(t, "Not installed", formatLocalStatus(localMODStatus{}))
	assert.Equal(t, "Disabled", formatLocalStatus(localMODStatus{Installed: true}))
	assert.Equal(t, "Enabled", formatLocalStatus(localMODStatus{Installed: true, Enabled: true}))
}

func TestJSONLocalStatus(t *testing.T) {
	assert.Equal(t, "not_installed", jsonLocalStatus(localMODStatus{}))
	assert.Equal(t, "disabled", jsonLocalStatus(localMODStatus{Installed: true}))
	assert.Equal(t, "enabled", jsonLocalStatus(localMODStatus{Installed: true, Enabled: true}))
}

func TestDisplayShow(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	var buf bytes.Buffer
	p := &printer{out: &buf}

	displayShow(p, sampleShowMODInfo(), localMODStatus{})

	out := buf.String()
	assert.Contains(t, out, "Some MOD")
	assert.Contains(t, out, "A test MOD")
	assert.Contains(t, out, "Status")
	assert.Contains(t, out, "Not installed")
	assert.Contains(t, out, "Content") // category display name
	assert.Contains(t, out, "MIT License")
	assert.Contains(t, out, "Source: https://example.com/src")
	assert.Contains(t, out, "Dependencies")
	assert.Contains(t, out, "  base")
	assert.Contains(t, out, "Optional Dependencies")
	assert.Contains(t, out, "optional-lib")
	assert.Contains(t, out, "Incompatibilities")
	assert.Contains(t, out, "bad-mod")
	assert.NotContains(t, out, "neutral-mod") // load-neutral is parsed and discarded
}

func TestDisplayShowUpdateAvailable(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	var buf bytes.Buffer
	p := &printer{out: &buf}

	local := mod.MODVersion{Major: 1}
	displayShow(p, sampleShowMODInfo(), localMODStatus{Installed: true, Enabled: true, LocalVersion: &local})

	out := buf.String()
	assert.Contains(t, out, "Enabled")
	assert.Contains(t, out, "Installed Version")
	assert.Contains(t, out, "1.0.0 (update available)")
}

func TestOutputShowJSON(t *testing.T) {
	var buf bytes.Buffer
	p := &printer{out: &buf}

	require.NoError(t, outputShowJSON(p, sampleShowMODInfo(), localMODStatus{}))

	out := buf.String()
	assert.Contains(t, out, `"status": "not_installed"`)
	assert.Contains(t, out, `"category": "Content"`) // JSON uses .name, unlike search's .value
	assert.Contains(t, out, `"latest_version": "2.0.0"`)
	assert.Contains(t, out, `"installed_version": null`)
	assert.Contains(t, out, `"mod_portal": "https://mods.factorio.com/mod/some-mod"`)
}
