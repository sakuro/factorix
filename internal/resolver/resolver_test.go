package resolver

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/mod"
)

// fakePortal serves canned MODInfo responses.
type fakePortal struct {
	mu   sync.Mutex
	mods map[string]*api.MODInfo
}

func (f *fakePortal) GetMODFull(_ context.Context, name string) (*api.MODInfo, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	info, ok := f.mods[name]
	if !ok {
		return nil, fmt.Errorf("%w: %s", api.ErrMODNotOnPortal, name)
	}
	return info, nil
}

// modInfo builds a MODInfo with one release per version string; the last
// version listed carries the given dependency strings.
func modInfo(t *testing.T, name string, deps []string, versions ...string) *api.MODInfo {
	t.Helper()
	info := &api.MODInfo{Name: name}
	for i, vs := range versions {
		v, err := mod.ParseMODVersion(vs)
		require.NoError(t, err)
		release := api.Release{Version: v, FileName: name + "_" + vs + ".zip"}
		if i == len(versions)-1 {
			release.InfoJSON.Dependencies = deps
		}
		info.Releases = append(info.Releases, release)
	}
	return info
}

func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

func TestFetch(t *testing.T) {
	portal := &fakePortal{mods: map[string]*api.MODInfo{
		"alpha": modInfo(t, "alpha", nil, "1.0.0", "1.1.0"),
		"beta":  modInfo(t, "beta", nil, "2.0.0"),
	}}
	r := &Resolver{Portal: portal, Logger: discardLogger()}

	t.Run("resolves latest and exact specs", func(t *testing.T) {
		fetched, err := r.Fetch(context.Background(), []Spec{
			{MOD: mod.MOD{Name: "alpha"}, Latest: true},
			{MOD: mod.MOD{Name: "beta"}, Version: mustVersion(t, "2.0.0")},
		}, 2)
		require.NoError(t, err)
		require.Len(t, fetched, 2)
		assert.Equal(t, "1.1.0", fetched[0].Release.Version.String())
		assert.Equal(t, "2.0.0", fetched[1].Release.Version.String())
		assert.NotNil(t, fetched[0].Info)
	})

	t.Run("unknown MOD fails the call", func(t *testing.T) {
		_, err := r.Fetch(context.Background(), []Spec{{MOD: mod.MOD{Name: "ghost"}, Latest: true}}, 1)
		require.Error(t, err)
	})

	t.Run("missing release fails with spec label", func(t *testing.T) {
		_, err := r.Fetch(context.Background(), []Spec{{MOD: mod.MOD{Name: "beta"}, Version: mustVersion(t, "9.9.9")}}, 1)
		require.ErrorContains(t, err, "beta@9.9.9")
	})
}

func TestSpecVersionLabel(t *testing.T) {
	assert.Equal(t, "latest", Spec{MOD: mod.MOD{Name: "a"}, Latest: true}.VersionLabel())
	assert.Equal(t, "1.2.0", Spec{MOD: mod.MOD{Name: "a"}, Version: mustVersion(t, "1.2.0")}.VersionLabel())
}
