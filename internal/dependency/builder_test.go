package dependency

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
)

func installedMOD(name, version string, deps ...string) mod.InstalledMOD {
	v, err := mod.ParseMODVersion(version)
	if err != nil {
		panic(err)
	}
	return mod.InstalledMOD{
		MOD:     mod.MOD{Name: name},
		Version: v,
		Form:    mod.FormZIP,
		Info: mod.InfoJSON{
			Name:         name,
			Version:      v,
			Title:        name,
			Author:       "test",
			Dependencies: deps,
		},
	}
}

func TestBuildGraph(t *testing.T) {
	installed := []mod.InstalledMOD{
		installedMOD("base", "2.0.0"),
		installedMOD("lib", "1.0.0", "base"),
		installedMOD("app", "1.0.0", "base", "lib >= 1.0.0", "? extra"),
	}
	list := mod.NewMODList()
	require.NoError(t, list.Add(mod.MOD{Name: "base"}, mod.MODState{Enabled: true}))
	require.NoError(t, list.Add(mod.MOD{Name: "lib"}, mod.MODState{Enabled: true}))
	require.NoError(t, list.Add(mod.MOD{Name: "app"}, mod.MODState{Enabled: false}))

	graph, err := BuildGraph(installed, list)
	require.NoError(t, err)

	assert.Equal(t, 3, graph.Len())

	app, ok := graph.Node(mod.MOD{Name: "app"})
	require.True(t, ok)
	assert.False(t, app.Enabled)
	assert.True(t, app.Installed)

	// Edges to the base MOD are skipped; optional edges are kept.
	appEdges := graph.EdgesFrom(mod.MOD{Name: "app"})
	require.Len(t, appEdges, 2)
	assert.Equal(t, mod.MOD{Name: "lib"}, appEdges[0].To)
	assert.Equal(t, TypeRequired, appEdges[0].Type)
	assert.Equal(t, mod.MOD{Name: "extra"}, appEdges[1].To)
	assert.Equal(t, TypeOptional, appEdges[1].Type)

	assert.Empty(t, graph.EdgesFrom(mod.MOD{Name: "lib"}))
}

func TestBuildGraphVersionSelection(t *testing.T) {
	installed := []mod.InstalledMOD{
		installedMOD("multi", "1.0.0"),
		installedMOD("multi", "2.0.0"),
		installedMOD("pinned", "1.0.0"),
		installedMOD("pinned", "2.0.0"),
	}
	pinnedVersion := mod.MODVersion{Major: 1}
	list := mod.NewMODList()
	require.NoError(t, list.Add(mod.MOD{Name: "multi"}, mod.MODState{Enabled: true}))
	require.NoError(t, list.Add(mod.MOD{Name: "pinned"}, mod.MODState{Enabled: true, Version: &pinnedVersion}))

	graph, err := BuildGraph(installed, list)
	require.NoError(t, err)

	// Without a pin the newest installed version wins.
	multi, ok := graph.Node(mod.MOD{Name: "multi"})
	require.True(t, ok)
	assert.Equal(t, mod.MODVersion{Major: 2}, multi.Version)

	// A pinned version wins when that exact version is installed.
	pinned, ok := graph.Node(mod.MOD{Name: "pinned"})
	require.True(t, ok)
	assert.Equal(t, mod.MODVersion{Major: 1}, pinned.Version)
}

func TestBuildGraphInvalidDependency(t *testing.T) {
	installed := []mod.InstalledMOD{installedMOD("broken", "1.0.0", ">= 1.0")}
	list := mod.NewMODList()

	_, err := BuildGraph(installed, list)
	var parseErr *ParseError
	require.ErrorAs(t, err, &parseErr)
}
