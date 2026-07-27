package resolver

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

func release(t *testing.T, version string) api.Release {
	t.Helper()
	v, err := mod.ParseMODVersion(version)
	require.NoError(t, err)
	return api.Release{Version: v, FileName: "test-mod_" + version + ".zip"}
}

func mustVersion(t *testing.T, s string) mod.MODVersion {
	t.Helper()
	v, err := mod.ParseMODVersion(s)
	require.NoError(t, err)
	return v
}

func TestSelectLatest(t *testing.T) {
	older := release(t, "1.0.0")
	newer := release(t, "1.1.0")

	t.Run("prefers latest_release when present", func(t *testing.T) {
		pinned := release(t, "1.0.0")
		info := &api.MODInfo{LatestRelease: &pinned, Releases: []api.Release{older, newer}}
		got := SelectLatest(info)
		require.NotNil(t, got)
		assert.Equal(t, "1.0.0", got.Version.String())
	})

	t.Run("falls back to highest version", func(t *testing.T) {
		// Descending order proves selection is by version, not list position.
		info := &api.MODInfo{Releases: []api.Release{newer, older}}
		got := SelectLatest(info)
		require.NotNil(t, got)
		assert.Equal(t, "1.1.0", got.Version.String())
	})

	t.Run("nil when no releases", func(t *testing.T) {
		assert.Nil(t, SelectLatest(&api.MODInfo{}))
	})
}

func TestSelectExact(t *testing.T) {
	info := &api.MODInfo{Releases: []api.Release{release(t, "1.0.0"), release(t, "1.1.0")}}

	got := SelectExact(info, mustVersion(t, "1.0.0"))
	require.NotNil(t, got)
	assert.Equal(t, "1.0.0", got.Version.String())

	assert.Nil(t, SelectExact(info, mustVersion(t, "9.9.9")))
}

func TestSelectCompatible(t *testing.T) {
	v1 := release(t, "1.0.0")
	v2 := release(t, "2.0.0")
	info := &api.MODInfo{Releases: []api.Release{v1, v2}}

	t.Run("nil requirement selects latest", func(t *testing.T) {
		got := SelectCompatible(info, nil)
		require.NotNil(t, got)
		assert.Equal(t, "2.0.0", got.Version.String())
	})

	t.Run("highest version satisfying the requirement", func(t *testing.T) {
		requirement := &dependency.VersionRequirement{Operator: dependency.OpLessEqual, Version: mustVersion(t, "1.5.0")}
		got := SelectCompatible(info, requirement)
		require.NotNil(t, got)
		assert.Equal(t, "1.0.0", got.Version.String())
	})

	t.Run("latest_release wins when it satisfies", func(t *testing.T) {
		pinned := release(t, "1.0.0")
		withLatest := &api.MODInfo{LatestRelease: &pinned, Releases: []api.Release{v1, v2}}
		requirement := &dependency.VersionRequirement{Operator: dependency.OpLessEqual, Version: mustVersion(t, "2.0.0")}
		got := SelectCompatible(withLatest, requirement)
		require.NotNil(t, got)
		assert.Equal(t, "1.0.0", got.Version.String())
	})

	t.Run("unsatisfying latest_release is ignored", func(t *testing.T) {
		pinned := release(t, "2.0.0")
		withLatest := &api.MODInfo{LatestRelease: &pinned, Releases: []api.Release{v1, v2}}
		requirement := &dependency.VersionRequirement{Operator: dependency.OpLessEqual, Version: mustVersion(t, "1.5.0")}
		got := SelectCompatible(withLatest, requirement)
		require.NotNil(t, got)
		assert.Equal(t, "1.0.0", got.Version.String())
	})

	t.Run("nil when nothing satisfies", func(t *testing.T) {
		requirement := &dependency.VersionRequirement{Operator: dependency.OpGreaterEqual, Version: mustVersion(t, "9.0.0")}
		assert.Nil(t, SelectCompatible(info, requirement))
	})

	t.Run("multiple requirements narrow the selection", func(t *testing.T) {
		multi := &api.MODInfo{Releases: []api.Release{release(t, "1.0.0"), release(t, "1.5.0"), release(t, "2.0.0")}}
		lower := &dependency.VersionRequirement{Operator: dependency.OpGreaterEqual, Version: mustVersion(t, "1.2.0")}
		upper := &dependency.VersionRequirement{Operator: dependency.OpLessEqual, Version: mustVersion(t, "1.8.0")}
		got := SelectCompatible(multi, lower, upper)
		require.NotNil(t, got)
		assert.Equal(t, "1.5.0", got.Version.String())
	})

	t.Run("nil entries among requirements are ignored", func(t *testing.T) {
		requirement := &dependency.VersionRequirement{Operator: dependency.OpLessEqual, Version: mustVersion(t, "1.5.0")}
		got := SelectCompatible(info, nil, requirement, nil)
		require.NotNil(t, got)
		assert.Equal(t, "1.0.0", got.Version.String())
	})
}
