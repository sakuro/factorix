package cli

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

func release(version string, releasedAt time.Time) api.Release {
	v, err := mod.ParseMODVersion(version)
	if err != nil {
		panic(err)
	}
	return api.Release{Version: v, ReleasedAt: releasedAt, FileName: "test-mod_" + version + ".zip"}
}

func TestParseMODSpec(t *testing.T) {
	tests := []struct {
		input string
		want  modSpec
	}{
		{"some-mod", modSpec{MOD: mod.MOD{Name: "some-mod"}, Latest: true}},
		{"some-mod@latest", modSpec{MOD: mod.MOD{Name: "some-mod"}, Latest: true}},
		{"some-mod@", modSpec{MOD: mod.MOD{Name: "some-mod"}, Latest: true}},
		{"some-mod@1.2.0", modSpec{MOD: mod.MOD{Name: "some-mod"}, Version: mod.MODVersion{Major: 1, Minor: 2}}},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got, err := parseMODSpec(tt.input)
			require.NoError(t, err)
			assert.Equal(t, tt.want, got)
		})
	}

	_, err := parseMODSpec("some-mod@not-a-version")
	require.Error(t, err)
}

func TestFindRelease(t *testing.T) {
	older := release("1.0.0", time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC))
	newer := release("1.1.0", time.Date(2024, 6, 1, 0, 0, 0, 0, time.UTC))
	info := &api.MODInfo{Releases: []api.Release{older, newer}}

	got := findRelease(info, modSpec{Latest: true})
	require.NotNil(t, got)
	assert.Equal(t, "1.1.0", got.Version.String())

	got = findRelease(info, modSpec{Version: mod.MODVersion{Major: 1}})
	require.NotNil(t, got)
	assert.Equal(t, "1.0.0", got.Version.String())

	got = findRelease(info, modSpec{Version: mod.MODVersion{Major: 9}})
	assert.Nil(t, got)
}

func TestFindCompatibleRelease(t *testing.T) {
	v1 := release("1.0.0", time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC))
	v2 := release("2.0.0", time.Date(2024, 6, 1, 0, 0, 0, 0, time.UTC))
	info := &api.MODInfo{Releases: []api.Release{v1, v2}}

	got := findCompatibleRelease(info, nil)
	require.NotNil(t, got)
	assert.Equal(t, "2.0.0", got.Version.String())

	requirement := &dependency.VersionRequirement{Operator: dependency.OpLessEqual, Version: mod.MODVersion{Major: 1}}
	got = findCompatibleRelease(info, requirement)
	require.NotNil(t, got)
	assert.Equal(t, "1.0.0", got.Version.String())

	requirement = &dependency.VersionRequirement{Operator: dependency.OpGreaterEqual, Version: mod.MODVersion{Major: 9}}
	assert.Nil(t, findCompatibleRelease(info, requirement))
}

func TestValidateFilename(t *testing.T) {
	require.NoError(t, validateFilename("test-mod_1.0.0.zip"))

	for _, bad := range []string{"", "a/b.zip", `a\b.zip`, "../escape.zip"} {
		require.Error(t, validateFilename(bad), bad)
	}
}

func TestBuildDownloadTargets(t *testing.T) {
	infos := []fetchedMODInfo{
		{MOD: mod.MOD{Name: "some-mod"}, MODInfo: &api.MODInfo{Name: "some-mod"}, Release: release("1.0.0", time.Now())},
	}
	targets, err := buildDownloadTargets(infos, "/tmp/downloads")
	require.NoError(t, err)
	require.Len(t, targets, 1)
	assert.Equal(t, "/tmp/downloads/test-mod_1.0.0.zip", targets[0].OutputPath)

	infos[0].Release.FileName = "../escape.zip"
	_, err = buildDownloadTargets(infos, "/tmp/downloads")
	require.ErrorIs(t, err, errInvalidFilename)
}

func TestCollectNewDependencies(t *testing.T) {
	known := map[string]fetchedMODInfo{
		"app": {
			MOD: mod.MOD{Name: "app"},
			Release: api.Release{InfoJSON: api.ReleaseInfoJSON{
				Dependencies: []string{"base", "lib >= 1.0", "? optional-lib", "elevated-rails"},
			}},
		},
	}
	deps := collectNewDependencies([]string{"app"}, known, map[string]bool{})
	require.Len(t, deps, 1)
	assert.Equal(t, "lib", deps[0].name)
	require.NotNil(t, deps[0].requirement)
	assert.Equal(t, dependency.OpGreaterEqual, deps[0].requirement.Operator)

	// Already-processed names yield nothing on a second pass.
	assert.Empty(t, collectNewDependencies([]string{"app"}, known, map[string]bool{"app": true}))
}
