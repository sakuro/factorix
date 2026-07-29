# Resolution Engine Unification Implementation Plan (PR2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two parallel dependency-resolution BFS implementations (`resolveInstallDependencies`, `resolveDownloadDependencies`) with a single graph-based engine, `Resolver.Resolve`, in `internal/resolver`. Closes #181.

**Architecture:** `internal/resolver` gains a `Resolver` (Portal client + logger) with two entry points: `Fetch` (resolve explicit specs to releases, hard failure) and `Resolve` (Fetch + extend a `dependency.Graph` with transitive required/recommended dependencies, warn-and-skip). install and sync pass the installed-MOD graph; download passes a fresh empty graph (recursive) or calls `Fetch` (non-recursive). `cli.modSpec` moves to `resolver.Spec`.

**Tech Stack:** Go, testify, `golang.org/x/sync/errgroup`, `mise run default` for verification.

This is PR2 of the plan in
`docs/superpowers/specs/2026-07-27-dependency-resolution-unification-design.md`.

## Global Constraints

- Commit messages: English, `:emoji:` prefix. No AI attribution, no trailers.
- Code comments and doc comments: English. "MOD" is uppercase in exported identifiers and user-facing text.
- Every task ends with `mise run test` green; the branch ends with `mise run default` green.
- `internal/resolver` may depend on `internal/api`, `internal/dependency`, `internal/mod` (plus stdlib, errgroup, testify). `internal/dependency` must stay free of `api` imports.
- Decided behavior changes (spec "Behavioral policy"): (1) `mod download --recursive` follows required + recommended dependencies by default and gains `--ignore-recommended`; (2) base/expansion MODs are never fetched from the Portal during dependency resolution (previously install/sync queried expansions and warned on 404, and download used a hardcoded `builtinMODs` list).
- Explicitly requested MODs fail hard when unresolvable; transitively discovered dependencies are skipped with a warning.

---

### Task 1: `resolver.Spec` and `Resolver.Fetch`

**Files:**
- Create: `internal/resolver/spec.go`
- Create: `internal/resolver/resolver.go`
- Create: `internal/resolver/resolver_test.go`

**Interfaces:**
- Consumes: `SelectLatest`, `SelectExact` from `internal/resolver/select.go` (already on main); `api.MODInfo`, `api.Release`, `mod.MOD`, `mod.MODVersion`.
- Produces (Tasks 2-3 rely on these exact shapes):
  - `type Spec struct { MOD mod.MOD; Latest bool; Version mod.MODVersion }` with methods `Select(info *api.MODInfo) *api.Release` and `VersionLabel() string`
  - `type Portal interface { GetMODFull(ctx context.Context, name string) (*api.MODInfo, error) }` (satisfied by `*api.MODPortalAPI`)
  - `type Resolver struct { Portal Portal; Logger *slog.Logger }`
  - `type Fetched struct { MOD mod.MOD; Info *api.MODInfo; Release api.Release }`
  - `func (r *Resolver) Fetch(ctx context.Context, specs []Spec, jobs int) ([]Fetched, error)`
  - unexported `concurrentFetch(ctx, jobs, specs, resolve)` used again in Task 2

- [ ] **Step 1: Write the failing tests**

Create `internal/resolver/resolver_test.go`:

```go
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

// fakePortal serves canned MODInfo responses and records which MOD names
// were requested (concurrently, hence the mutex).
type fakePortal struct {
	mu        sync.Mutex
	mods      map[string]*api.MODInfo
	requested []string
}

func (f *fakePortal) GetMODFull(_ context.Context, name string) (*api.MODInfo, error) {
	f.mu.Lock()
	f.requested = append(f.requested, name)
	f.mu.Unlock()
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
```

`mustVersion` already exists in `internal/resolver/select_test.go` (same package) — do not redefine it. `api.ErrMODNotOnPortal` exists in `internal/api`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/resolver/`
Expected: FAIL to build (`Spec`, `Resolver` undefined).

- [ ] **Step 3: Implement `spec.go` and `resolver.go`**

Create `internal/resolver/spec.go`:

```go
package resolver

import (
	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/mod"
)

// Spec is a parsed MOD specification: a name plus either "latest" or an
// exact version.
type Spec struct {
	MOD     mod.MOD
	Latest  bool
	Version mod.MODVersion // meaningless when Latest
}

// Select returns the release the spec designates, or nil when absent.
func (s Spec) Select(info *api.MODInfo) *api.Release {
	if s.Latest {
		return SelectLatest(info)
	}
	return SelectExact(info, s.Version)
}

// VersionLabel renders the requested version for error messages.
func (s Spec) VersionLabel() string {
	if s.Latest {
		return "latest"
	}
	return s.Version.String()
}
```

Create `internal/resolver/resolver.go`:

```go
package resolver

import (
	"context"
	"fmt"
	"log/slog"

	"golang.org/x/sync/errgroup"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/mod"
)

// Portal is the subset of the MOD Portal API the resolver needs. Only the
// full endpoint is usable here: /full is the only response that carries
// each release's dependencies.
type Portal interface {
	GetMODFull(ctx context.Context, name string) (*api.MODInfo, error)
}

// Resolver fetches MODs from the Portal and resolves their dependencies.
type Resolver struct {
	Portal Portal
	Logger *slog.Logger
}

// Fetched pairs a requested MOD with its full info and selected release.
type Fetched struct {
	MOD     mod.MOD
	Info    *api.MODInfo
	Release api.Release
}

// Fetch resolves each spec to a release with up to jobs concurrent Portal
// requests. Any spec that cannot be fetched or has no matching release
// fails the whole call: these are MODs the user explicitly asked for.
func (r *Resolver) Fetch(ctx context.Context, specs []Spec, jobs int) ([]Fetched, error) {
	return concurrentFetch(ctx, jobs, specs, func(ctx context.Context, spec Spec) (Fetched, error) {
		info, err := r.Portal.GetMODFull(ctx, spec.MOD.Name)
		if err != nil {
			return Fetched{}, err
		}
		release := spec.Select(info)
		if release == nil {
			return Fetched{}, fmt.Errorf("Release not found for %s@%s", spec.MOD.Name, spec.VersionLabel())
		}
		return Fetched{MOD: spec.MOD, Info: info, Release: *release}, nil
	})
}

// concurrentFetch runs resolve for each spec, jobs at a time, preserving
// input order in the results.
func concurrentFetch(ctx context.Context, jobs int, specs []Spec, resolve func(context.Context, Spec) (Fetched, error)) ([]Fetched, error) {
	results := make([]Fetched, len(specs))
	group, ctx := errgroup.WithContext(ctx)
	group.SetLimit(jobs)
	for i, spec := range specs {
		group.Go(func() error {
			result, err := resolve(ctx, spec)
			if err != nil {
				return err
			}
			results[i] = result
			return nil
		})
	}
	if err := group.Wait(); err != nil {
		return nil, err
	}
	return results, nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `go test ./internal/resolver/`
Expected: PASS. Also run `go vet ./internal/resolver/` and `mise run lint`.

- [ ] **Step 5: Commit**

```bash
git add internal/resolver
git commit -m ":sparkles: Add resolver.Spec and Resolver.Fetch"
```

---

### Task 2: `Resolver.Resolve` — the unified dependency engine

**Files:**
- Modify: `internal/resolver/resolver.go` (append `Options`, `Resolve`, `resolveDependencies`, `missingDependency`)
- Modify: `internal/resolver/resolver_test.go` (append `TestResolve`)

**Interfaces:**
- Consumes: `Spec`, `Fetched`, `Resolver`, `concurrentFetch` from Task 1; `SelectCompatible` from select.go; `dependency.Graph` methods `AddUninstalledMOD`, `EdgesFrom`, `Contains`, `Node`; `dependency.TypeRequired`, `TypeRecommended`; `mod.MOD.IsBase/IsExpansion`.
- Produces (Task 3 relies on):
  - `type Options struct { Jobs int; FollowRecommended bool }`
  - `func (r *Resolver) Resolve(ctx context.Context, graph *dependency.Graph, specs []Spec, opts Options) (map[mod.MOD]api.Release, error)`
  - Contract: the returned map holds the selected release for **every spec** (even ones whose node already existed in the graph) and for every transitive dependency the call added; skipped dependencies and pre-existing graph nodes reached as dependencies are absent.

- [ ] **Step 1: Write the failing tests**

Append to `internal/resolver/resolver_test.go`:

```go
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
			"app": modInfo(t, "app", []string{"lib"}, "1.0.0"),
			"lib": modInfo(t, "lib", []string{"core"}, "1.0.0"),
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
```

Add `"github.com/sakuro/factorix/internal/dependency"` to the test file imports.

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/resolver/`
Expected: FAIL to build (`Options`, `Resolve` undefined).

- [ ] **Step 3: Implement `Resolve`**

Append to `internal/resolver/resolver.go` (add `"github.com/sakuro/factorix/internal/dependency"` to imports):

```go
// Options tunes Resolve.
type Options struct {
	Jobs              int  // concurrent Portal requests
	FollowRecommended bool // also follow recommended dependency edges
}

// Resolve fetches each spec from the Portal, adds it to graph (via
// AddUninstalledMOD), then walks required (and, per opts, recommended)
// edges breadth-first, fetching MODs not yet in the graph and extending it
// until the frontier is empty. It returns the selected release for every
// spec and every dependency it added. Explicitly requested specs fail
// hard; a transitive dependency that cannot be fetched or has no release
// satisfying its version requirement is skipped with a warning. Base and
// expansion MODs are never fetched.
func (r *Resolver) Resolve(ctx context.Context, graph *dependency.Graph, specs []Spec, opts Options) (map[mod.MOD]api.Release, error) {
	initial, err := r.Fetch(ctx, specs, opts.Jobs)
	if err != nil {
		return nil, err
	}

	releases := make(map[mod.MOD]api.Release, len(initial))
	frontier := make([]mod.MOD, 0, len(initial))
	for _, f := range initial {
		if err := graph.AddUninstalledMOD(f.MOD, f.Release.Version, f.Release.InfoJSON.Dependencies); err != nil {
			return nil, err
		}
		releases[f.MOD] = f.Release
		frontier = append(frontier, f.MOD)
	}

	if err := r.resolveDependencies(ctx, graph, releases, frontier, opts); err != nil {
		return nil, err
	}
	return releases, nil
}

// missingDependency is a dependency edge pointing at a MOD not yet in the
// graph, remembered with its requirement and dependent for fetching.
type missingDependency struct {
	mod         mod.MOD
	requirement *dependency.VersionRequirement
	requiredBy  mod.MOD
}

func (r *Resolver) resolveDependencies(ctx context.Context, graph *dependency.Graph, releases map[mod.MOD]api.Release, frontier []mod.MOD, opts Options) error {
	processed := map[mod.MOD]bool{}
	for len(frontier) > 0 {
		var missing []missingDependency
		for _, m := range frontier {
			if processed[m] {
				continue
			}
			processed[m] = true
			for _, edge := range graph.EdgesFrom(m) {
				relevant := edge.Type == dependency.TypeRequired || (opts.FollowRecommended && edge.Type == dependency.TypeRecommended)
				if !relevant {
					continue
				}
				// The base MOD and the official expansions are not on the
				// Portal; they are installed with the game, never fetched.
				if edge.To.IsBase() || edge.To.IsExpansion() {
					continue
				}
				if graph.Contains(edge.To) {
					continue
				}
				missing = append(missing, missingDependency{mod: edge.To, requirement: edge.Requirement, requiredBy: m})
			}
		}
		frontier = nil
		if len(missing) == 0 {
			continue
		}

		specs := make([]Spec, len(missing))
		for i, dep := range missing {
			specs[i] = Spec{MOD: dep.mod, Latest: true}
		}
		results, err := concurrentFetch(ctx, opts.Jobs, specs, func(ctx context.Context, spec Spec) (Fetched, error) {
			var requirement *dependency.VersionRequirement
			var requiredBy mod.MOD
			for _, dep := range missing {
				if dep.mod == spec.MOD {
					requirement = dep.requirement
					requiredBy = dep.requiredBy
					break
				}
			}
			info, err := r.Portal.GetMODFull(ctx, spec.MOD.Name)
			if err != nil {
				r.Logger.Warn("Skipping dependency", "mod", spec.MOD.Name, "required_by", requiredBy.Name, "reason", err)
				return Fetched{}, nil
			}
			release := SelectCompatible(info, requirement)
			if release == nil {
				r.Logger.Warn("Skipping dependency", "mod", spec.MOD.Name, "required_by", requiredBy.Name, "reason", "no compatible release found")
				return Fetched{}, nil
			}
			return Fetched{MOD: spec.MOD, Info: info, Release: *release}, nil
		})
		if err != nil {
			return err
		}

		for _, f := range results {
			if f.Info == nil {
				continue // skipped above with a warning
			}
			if err := graph.AddUninstalledMOD(f.MOD, f.Release.Version, f.Release.InfoJSON.Dependencies); err != nil {
				return err
			}
			releases[f.MOD] = f.Release
			frontier = append(frontier, f.MOD)
		}
	}
	return nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `go test ./internal/resolver/`
Expected: PASS. Also `go vet ./internal/resolver/` and `mise run lint`.

- [ ] **Step 5: Commit**

```bash
git add internal/resolver
git commit -m ":sparkles: Add Resolver.Resolve dependency engine"
```

---

### Task 3: Migrate install, sync, and download; delete the legacy resolvers

**Files:**
- Modify: `internal/cli/download_support.go` (delete `modSpec`, `fetchedMODInfo`, `fetchMODInfoConcurrently`, `selectRelease`; rework `parseMODSpec`, `buildDownloadTargets`; add `releaseDownloadTargets`; drop `downloadTarget.MODInfo`)
- Modify: `internal/cli/mod_install.go` (Resolve call; delete `resolveInstallDependencies`)
- Modify: `internal/cli/mod_sync.go` (Resolve call; fold target building)
- Modify: `internal/cli/mod_download.go` (Fetch/Resolve; delete `resolveDownloadDependencies`, `collectNewDependencies`, `requiredDependency`, `warnAndSkip`, `specVersionLabel`, `builtinMODs`; add `--ignore-recommended`)
- Modify: `internal/cli/download_support_test.go`, other cli tests as reconciliation requires
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `resolver.Spec` (fields `MOD`, `Latest`, `Version`), `resolver.Resolver{Portal, Logger}`, `resolver.Options{Jobs, FollowRecommended}`, `Resolver.Fetch(ctx, specs, jobs) ([]resolver.Fetched, error)`, `Resolver.Resolve(ctx, graph, specs, opts) (map[mod.MOD]api.Release, error)`, `resolver.Fetched{MOD, Info, Release}`.
- Produces: `parseMODSpec(spec string) (resolver.Spec, error)`; `buildDownloadTargets(fetched []resolver.Fetched, outputDir string) ([]downloadTarget, error)`; `releaseDownloadTargets(releases map[mod.MOD]api.Release, outputDir string) ([]downloadTarget, error)`.

- [ ] **Step 1: Rework `download_support.go`**

Delete `modSpec`, `selectRelease`, `fetchedMODInfo`, and `fetchMODInfoConcurrently`. Change `parseMODSpec` to return `resolver.Spec` (same parsing logic, construct `resolver.Spec{...}`). Remove the `MODInfo` field from `downloadTarget` (it is written but never read). Replace `buildDownloadTargets` and add `releaseDownloadTargets`:

```go
func buildDownloadTargets(fetched []resolver.Fetched, outputDir string) ([]downloadTarget, error) {
	targets := make([]downloadTarget, 0, len(fetched))
	for _, f := range fetched {
		if err := validateFilename(f.Release.FileName); err != nil {
			return nil, err
		}
		targets = append(targets, downloadTarget{
			MOD:        f.MOD,
			Release:    f.Release,
			OutputPath: filepath.Join(outputDir, f.Release.FileName),
		})
	}
	return targets, nil
}

// releaseDownloadTargets converts a Resolve result into download targets
// (order follows map iteration; downloads run concurrently anyway).
func releaseDownloadTargets(releases map[mod.MOD]api.Release, outputDir string) ([]downloadTarget, error) {
	targets := make([]downloadTarget, 0, len(releases))
	for m, release := range releases {
		if err := validateFilename(release.FileName); err != nil {
			return nil, err
		}
		targets = append(targets, downloadTarget{
			MOD:        m,
			Release:    release,
			OutputPath: filepath.Join(outputDir, release.FileName),
		})
	}
	return targets, nil
}
```

- [ ] **Step 2: Migrate `mod_install.go`**

Replace the body of `planInstall` between the `PortalAPI()` call and the `MarkDisabledDependenciesForEnable` line with a single Resolve call, and delete `resolveInstallDependencies`:

```go
func planInstall(ctx context.Context, application *app.App, graph *dependency.Graph, specs []resolver.Spec, jobs int, includeRecommended bool) ([]installTarget, error) {
	portalAPI, err := application.PortalAPI()
	if err != nil {
		return nil, err
	}
	res := &resolver.Resolver{Portal: portalAPI, Logger: application.Logger}
	releases, err := res.Resolve(ctx, graph, specs, resolver.Options{Jobs: jobs, FollowRecommended: includeRecommended})
	if err != nil {
		return nil, err
	}

	dependency.MarkDisabledDependenciesForEnable(graph, includeRecommended)
	if err := dependency.ValidateInstallGraph(graph); err != nil {
		return nil, err
	}
	// ... the existing targets loop over graph.Nodes() stays unchanged ...
}
```

The RunE closure's `specs` slice becomes `[]resolver.Spec` (the `parseMODSpec` result type change propagates).

- [ ] **Step 3: Migrate `mod_sync.go`**

In `planSyncInstallation`, replace the fetch + AddUninstalledMOD loop + `resolveInstallDependencies` call + two-stage target building with:

```go
	specs := make([]resolver.Spec, len(entries))
	for i, entry := range entries {
		specs[i] = resolver.Spec{MOD: mod.MOD{Name: entry.Name}, Latest: !strict, Version: entry.Version}
	}
	res := &resolver.Resolver{Portal: portal, Logger: application.Logger}
	releases, err := res.Resolve(ctx, graph, specs, resolver.Options{Jobs: jobs, FollowRecommended: includeRecommended})
	if err != nil {
		return nil, nil, err
	}

	requested := make(map[mod.MOD]bool, len(specs))
	for _, spec := range specs {
		requested[spec.MOD] = true
	}
	// Dependency-resolved MODs aren't in entries/saveMODs, so the caller
	// needs their names and versions to fold them into the save-driven
	// mod-list.json planning (see the RunE closure above).
	var dependencyEntries []save.MODEntry
	targets, err := releaseDownloadTargets(releases, modDir)
	if err != nil {
		return nil, nil, err
	}
	for m, release := range releases {
		if !requested[m] {
			dependencyEntries = append(dependencyEntries, save.MODEntry{Name: m.Name, Version: release.Version})
		}
	}

	result := make([]syncInstallTarget, len(targets))
	for i, target := range targets {
		result[i] = syncInstallTarget{downloadTarget: target}
	}
	return result, dependencyEntries, nil
```

Delete the now-stale comment about `Version` staying set "so error messages can name the save-file version" — the unified Fetch error labels latest-mode specs as `@latest`. This message change is accepted (unification of an incidental difference).

- [ ] **Step 4: Migrate `mod_download.go`**

Add the flag variable `ignoreRecommended` alongside `recursive`, register it, and update the `-r` help text:

```go
	cmd.Flags().BoolVarP(&recursive, "recursive", "r", false, "Include dependencies recursively (required and recommended)")
	cmd.Flags().BoolVar(&ignoreRecommended, "ignore-recommended", false, "Do not resolve recommended dependencies")
```

Replace `planDownload` and delete `resolveDownloadDependencies`, `collectNewDependencies`, `requiredDependency`, `warnAndSkip`, `specVersionLabel`, and the `builtinMODs` variable:

```go
func planDownload(ctx context.Context, application *app.App, specs []resolver.Spec, downloadDir string, jobs int, recursive, includeRecommended bool) ([]downloadTarget, error) {
	portalAPI, err := application.PortalAPI()
	if err != nil {
		return nil, err
	}
	res := &resolver.Resolver{Portal: portalAPI, Logger: application.Logger}

	if !recursive {
		fetched, err := res.Fetch(ctx, specs, jobs)
		if err != nil {
			return nil, err
		}
		return buildDownloadTargets(fetched, downloadDir)
	}

	// Installation state is irrelevant to a plain download, so resolution
	// runs against an empty graph: every dependency counts as missing.
	releases, err := res.Resolve(ctx, dependency.NewGraph(), specs, resolver.Options{Jobs: jobs, FollowRecommended: includeRecommended})
	if err != nil {
		return nil, err
	}
	return releaseDownloadTargets(releases, downloadDir)
}
```

The RunE closure passes `!ignoreRecommended` as the new argument. Remove imports that become unused (`errors`, `maps`, `slices`, `dependency` stays for `NewGraph`).

- [ ] **Step 5: Reconcile tests**

Run: `go build ./... && go test ./internal/cli/ ./internal/resolver/`

Expected mechanical updates:
- `download_support_test.go`: `TestParseMODSpec` expectations become `resolver.Spec{...}`; `TestCollectNewDependencies` is deleted (behavior now covered by `TestResolve`); `TestBuildDownloadTargets` switches to `[]resolver.Fetched`.
- Other failures are legitimate only if they map to one of the three decided changes: (a) download `--recursive` now also resolves recommended dependencies, (b) expansion/base dependencies are no longer requested from the mock Portal (fixtures asserting those requests or warnings change), (c) "Release not found" errors for latest-mode sync specs now say `@latest` instead of the save version. Anything else is a regression — fix the code, not the test. Document each expectation change and its category in the report.

- [ ] **Step 6: CHANGELOG entry**

Add under `[Unreleased]` → `### Changed` (create the subsection if the previous release consumed it; keep the existing entry style, one bullet, trailing issue reference):

```markdown
- `mod download --recursive` now resolves recommended dependencies as well (use `--ignore-recommended` to opt out), and dependency resolution across install/sync/download shares one engine that never queries the Portal for base/expansion MODs (#181)
```

Also check `grep -rn "recursive" README.md doc/` — update any prose describing `mod download -r` as "required dependencies only".

- [ ] **Step 7: Run the full check suite**

Run: `mise run default`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m ":recycle: Unify dependency resolution on Resolver.Resolve"
```

---

### Task 4: Pull request

- [ ] **Step 1: Push and open the PR**

Push the branch and create the PR with the `create-pr` skill. Title: `:recycle: Unify dependency resolution into Resolver.Resolve`. Body includes: summary (one engine, graph-based, replaces two BFS implementations), the three behavior changes from Task 3 Step 5, `Closes #181`, `Related to #184`. No AI attribution.

- [ ] **Step 2: Verify CI is green and report the PR URL**
