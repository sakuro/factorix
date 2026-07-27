package cli

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/resolver"
)

func release(version string) api.Release {
	v, err := mod.ParseMODVersion(version)
	if err != nil {
		panic(err)
	}
	return api.Release{Version: v, FileName: "test-mod_" + version + ".zip"}
}

func TestParseMODSpec(t *testing.T) {
	tests := []struct {
		input string
		want  resolver.Spec
	}{
		{"some-mod", resolver.Spec{MOD: mod.MOD{Name: "some-mod"}, Latest: true}},
		{"some-mod@latest", resolver.Spec{MOD: mod.MOD{Name: "some-mod"}, Latest: true}},
		{"some-mod@", resolver.Spec{MOD: mod.MOD{Name: "some-mod"}, Latest: true}},
		{"some-mod@1.2.0", resolver.Spec{MOD: mod.MOD{Name: "some-mod"}, Version: mod.MODVersion{Major: 1, Minor: 2}}},
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

func TestValidateFilename(t *testing.T) {
	require.NoError(t, validateFilename("test-mod_1.0.0.zip"))

	for _, bad := range []string{"", "a/b.zip", `a\b.zip`, "../escape.zip"} {
		require.Error(t, validateFilename(bad), bad)
	}
}

func TestBuildDownloadTargets(t *testing.T) {
	fetched := []resolver.Fetched{
		{MOD: mod.MOD{Name: "some-mod"}, Info: &api.MODInfo{Name: "some-mod"}, Release: release("1.0.0")},
	}
	targets, err := buildDownloadTargets(fetched, "/tmp/downloads")
	require.NoError(t, err)
	require.Len(t, targets, 1)
	assert.Equal(t, "/tmp/downloads/test-mod_1.0.0.zip", targets[0].OutputPath)

	fetched[0].Release.FileName = "../escape.zip"
	_, err = buildDownloadTargets(fetched, "/tmp/downloads")
	require.ErrorIs(t, err, errInvalidFilename)
}
