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
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

// fakePortal serves canned MODInfo responses.
type fakePortal struct {
	mu        sync.Mutex
	mods      map[string]*api.MODInfo
	requested []string
}

func (f *fakePortal) GetMODFull(_ context.Context, name string) (*api.MODInfo, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.requested = append(f.requested, name)
	info, ok := f.mods[name]
	if !ok {
		return nil, fmt.Errorf("%w: %s", api.ErrMODNotOnPortal, name)
	}
	return info, nil
}

func (f *fakePortal) requestedNames() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.requested...)
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

func TestResolve(t *testing.T) {
	newResolver := func(mods map[string]*api.MODInfo) (*Resolver, *fakePortal) {
		portal := &fakePortal{mods: mods}
		return &Resolver{Portal: portal, Logger: discardLogger()}, portal
	}
	latestSpec := func(name string) Spec {
		return Spec{MOD: mod.MOD{Name: name}, Latest: true}
	}

	t.Run("resolves required chain recursively", func(t *testing.T) {
		r, _ := newResolver(map[string]*api.MODInfo{
			"app":  modInfo(t, "app", []string{"lib"}, "1.0.0"),
			"lib":  modInfo(t, "lib", []string{"core"}, "1.0.0"),
			"core": modInfo(t, "core", nil, "1.0.0"),
		})
		graph := dependency.NewGraph()
		releases, err := r.Resolve(context.Background(), graph, []Spec{latestSpec("app")}, Options{Jobs: 2})
		require.NoError(t, err)
		assert.Len(t, releases, 3)
		assert.True(t, graph.Contains(mod.MOD{Name: "core"}))
	})

	t.Run("follows recommended only when enabled", func(t *testing.T) {
		mods := map[string]*api.MODInfo{
			"app":   modInfo(t, "app", []string{"+ extra"}, "1.0.0"),
			"extra": modInfo(t, "extra", nil, "1.0.0"),
		}
		r, _ := newResolver(mods)
		releases, err := r.Resolve(context.Background(), dependency.NewGraph(), []Spec{latestSpec("app")}, Options{Jobs: 2, FollowRecommended: true})
		require.NoError(t, err)
		assert.Contains(t, releases, mod.MOD{Name: "extra"})

		r2, portal2 := newResolver(mods)
		releases, err = r2.Resolve(context.Background(), dependency.NewGraph(), []Spec{latestSpec("app")}, Options{Jobs: 2})
		require.NoError(t, err)
		assert.NotContains(t, releases, mod.MOD{Name: "extra"})
		assert.NotContains(t, portal2.requestedNames(), "extra")
	})

	t.Run("honors dependency version requirements", func(t *testing.T) {
		r, _ := newResolver(map[string]*api.MODInfo{
			"app": modInfo(t, "app", []string{"lib <= 1.5.0"}, "1.0.0"),
			"lib": modInfo(t, "lib", nil, "1.0.0", "2.0.0"),
		})
		releases, err := r.Resolve(context.Background(), dependency.NewGraph(), []Spec{latestSpec("app")}, Options{Jobs: 2})
		require.NoError(t, err)
		assert.Equal(t, "1.0.0", releases[mod.MOD{Name: "lib"}].Version.String())
	})

	t.Run("never fetches base or expansion dependencies", func(t *testing.T) {
		r, portal := newResolver(map[string]*api.MODInfo{
			"app": modInfo(t, "app", []string{"base >= 2.0.0", "quality", "space-age"}, "1.0.0"),
		})
		releases, err := r.Resolve(context.Background(), dependency.NewGraph(), []Spec{latestSpec("app")}, Options{Jobs: 2})
		require.NoError(t, err)
		assert.Len(t, releases, 1)
		assert.Equal(t, []string{"app"}, portal.requestedNames())
	})

	t.Run("skips dependencies already in the graph", func(t *testing.T) {
		r, portal := newResolver(map[string]*api.MODInfo{
			"app": modInfo(t, "app", []string{"lib"}, "1.0.0"),
		})
		graph := dependency.NewGraph()
		require.NoError(t, graph.AddNode(dependency.Node{MOD: mod.MOD{Name: "lib"}, Version: mustVersion(t, "1.0.0"), Enabled: true, Installed: true}))
		releases, err := r.Resolve(context.Background(), graph, []Spec{latestSpec("app")}, Options{Jobs: 2})
		require.NoError(t, err)
		assert.NotContains(t, releases, mod.MOD{Name: "lib"})
		assert.NotContains(t, portal.requestedNames(), "lib")
	})

	t.Run("marks installed-but-disabled spec for enable and still returns its release", func(t *testing.T) {
		r, _ := newResolver(map[string]*api.MODInfo{
			"app": modInfo(t, "app", nil, "1.0.0"),
		})
		graph := dependency.NewGraph()
		require.NoError(t, graph.AddNode(dependency.Node{MOD: mod.MOD{Name: "app"}, Version: mustVersion(t, "1.0.0"), Installed: true}))
		releases, err := r.Resolve(context.Background(), graph, []Spec{latestSpec("app")}, Options{Jobs: 2})
		require.NoError(t, err)
		assert.Contains(t, releases, mod.MOD{Name: "app"})
		node, ok := graph.Node(mod.MOD{Name: "app"})
		require.True(t, ok)
		assert.Equal(t, dependency.OpEnable, node.Operation)
	})

	t.Run("skips unfetchable transitive dependency with warning", func(t *testing.T) {
		r, _ := newResolver(map[string]*api.MODInfo{
			"app": modInfo(t, "app", []string{"gone"}, "1.0.0"),
		})
		graph := dependency.NewGraph()
		releases, err := r.Resolve(context.Background(), graph, []Spec{latestSpec("app")}, Options{Jobs: 2})
		require.NoError(t, err)
		assert.NotContains(t, releases, mod.MOD{Name: "gone"})
		assert.False(t, graph.Contains(mod.MOD{Name: "gone"}))
	})

	t.Run("skips transitive dependency with no compatible release", func(t *testing.T) {
		r, _ := newResolver(map[string]*api.MODInfo{
			"app": modInfo(t, "app", []string{"lib >= 9.0.0"}, "1.0.0"),
			"lib": modInfo(t, "lib", nil, "1.0.0"),
		})
		releases, err := r.Resolve(context.Background(), dependency.NewGraph(), []Spec{latestSpec("app")}, Options{Jobs: 2})
		require.NoError(t, err)
		assert.NotContains(t, releases, mod.MOD{Name: "lib"})
	})
}
