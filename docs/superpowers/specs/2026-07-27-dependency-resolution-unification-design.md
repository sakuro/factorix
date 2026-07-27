# Dependency Resolution and MOD Command Unification

## Goal

The MOD management commands (`install`, `uninstall`, `enable`, `disable`,
`update`, `sync`, `download`) each implement their own copies of closely
related logic. The duplication makes maintenance hard: a fix in one command
does not reach its siblings, and the copies have already drifted (see #180).

Unify four areas, parameterizing intentional behavioral differences:

- **A. Portal fetch + recursive dependency resolution** — two parallel BFS
  implementations (`resolveInstallDependencies` in `mod_install.go`,
  `resolveDownloadDependencies` in `mod_download.go`) plus three copies of
  the initial fetch-and-select loop (install, sync, download).
- **B. Planning BFS** — `PlanEnable`, `PlanDisable`, and
  `MarkDisabledDependenciesForEnable` in `internal/dependency/plan.go` are
  three similar traversals differing in direction and edge filter.
- **C. mod-list.json mutation and package deletion** — the
  Contains/Enabled/Enable-or-Add pattern appears in `executeInstall`,
  `executeUpdates`, and `applySyncChange`; form-aware file deletion appears
  in `executeUninstall` and `executeSyncDeletions`.
- **D. Command skeleton** — the RequireGameStopped → loadMODState → plan →
  confirm → execute → backup+save sequence is repeated across commands.

## Behavioral policy

Unification is allowed to change observable behavior where the current
divergence is a historical accident rather than a design decision:

- **"latest" resolution (closes #180)**: unified on the Portal's
  `latest_release` field. This changes install/download/update (previously
  newest-by-release-date) and leaves sync effectively unchanged.
- **Builtin MOD skipping**: unified on `mod.MOD.IsBase() || IsExpansion()`.
  The hardcoded `builtinMODs` list in `mod_download.go` is removed. The
  install/sync path stops querying the Portal for expansion dependencies
  (previously it relied on the fetch failing with a warning).

Intentional differences stay as parameters:

- `download --recursive` follows required dependencies only; install/sync
  follow required + recommended (with `--ignore-recommended` opt-out).
- Explicitly requested MODs fail hard when unresolvable; transitively
  discovered dependencies are skipped with a warning.

## Component: `internal/resolver` (new package)

Depends on `internal/api`, `internal/dependency`, `internal/mod`.
`internal/dependency` stays free of `api` imports (pure graph algorithms).

### Release selection

```go
// SelectLatest returns info.LatestRelease when present, otherwise the
// release with the highest version (mod.MODVersion.Compare).
func SelectLatest(info *api.MODInfo) *api.Release

// SelectExact returns the release with exactly the given version, or nil.
func SelectExact(info *api.MODInfo, version mod.MODVersion) *api.Release

// SelectCompatible returns SelectLatest when requirement is nil. Otherwise
// it returns info.LatestRelease when that satisfies the requirement, else
// the highest-version release satisfying it, else nil.
func SelectCompatible(info *api.MODInfo, requirement *dependency.VersionRequirement) *api.Release
```

These replace `findRelease`, `findSyncRelease`, `findCompatibleRelease`,
and `latestByReleaseDate` in `internal/cli`. `mod update` uses
`SelectLatest` for its newer-version check.

### Spec

`cli.modSpec` moves here as `resolver.Spec` (same fields: `MOD`, `Latest`,
`Version`). The string parsing (`parseMODSpec`) stays in `internal/cli`;
`mod uninstall` keeps its own spec type (exact-version-only semantics).

### Resolution engine

```go
type Resolver struct {
    Portal api.PortalAPI // needs GetMODFull
    Logger *slog.Logger
}

type Options struct {
    Jobs              int  // parallel Portal requests
    FollowRecommended bool // also follow recommended edges
}

// Resolve fetches each spec from the Portal, adds it to graph (via
// AddUninstalledMOD), then walks required (and, per Options, recommended)
// edges breadth-first, fetching MODs not yet in the graph and extending it
// until the frontier is empty. It returns the selected release for every
// newly added MOD.
func (r *Resolver) Resolve(ctx context.Context, graph *dependency.Graph, specs []Spec, opts Options) (map[mod.MOD]api.Release, error)
```

Behavior details:

- Explicit specs: fetch with `GetMODFull`, select with `SelectLatest` /
  `SelectExact`; any failure aborts with an error.
- Transitive dependencies: select with `SelectCompatible`; fetch failure or
  no compatible release logs a warning and skips the MOD.
- Base and expansion MODs are never fetched or added.
- Fetches run concurrently through the existing
  `fetchMODInfoConcurrently`-style errgroup pattern (moves into resolver).

### Callers

- **install**: passes the installed-MOD graph; keeps
  `MarkDisabledDependenciesForEnable` + `ValidateInstallGraph` afterwards.
- **sync**: same graph flow; keeps its save-file-specific planning
  (conflicts, unlisted, strict-version deletions) on top.
- **download**: passes a fresh empty graph (installation state is
  irrelevant); non-recursive mode is a resolve without following any edges
  (implemented as a separate initial-fetch-only helper or an option).
- `resolveInstallDependencies`, `resolveDownloadDependencies`, and
  `collectNewDependencies` are deleted.

## Component: planning traversal (`internal/dependency/plan.go`)

An unexported traversal helper unifies the three BFS loops:

```go
type walkOptions struct {
    direction  walkDirection       // forward (EdgesFrom) or dependents
    followEdge func(Edge) bool     // whether to traverse this edge
    visit      func(mod.MOD) error // per-node action; an error aborts the walk
}
```

`PlanEnable`, `PlanDisable`, and `MarkDisabledDependenciesForEnable` are
reimplemented on top of it. Public API and behavior are unchanged; existing
tests in `plan_test.go` must pass unmodified. The exact helper signature may
be adjusted during implementation as long as the three functions share one
queue/visited loop.

## Component: mutation helpers

- `mod.InstalledMOD.Remove() error` — deletes the package from disk,
  handling `FormDirectory` vs zip. Used by uninstall and sync.
- `mod.MODList.EnsureEnabled(m MOD) (added bool, err error)` — enables an
  existing entry or adds a new enabled one. Used by install and update.
- `mod.MODList.Replace(m MOD, state MODState) error` — Remove + Add, for
  changing the recorded version/state atomically. Used by update and sync.

## Component: command skeleton (`internal/cli`)

One generic function, not a framework:

```go
type mutationOpts struct {
    yes             bool
    quiet           bool
    backupExtension string
    confirmPrompt   string
    emptyMessage    string
}

// runMODMutation: RequireGameStopped → loadMODState → plan → (empty? print
// emptyMessage, done) → show plan → confirm → execute → backup + save
// mod-list.json.
func runMODMutation[P any](cmd *cobra.Command, c *cli, opts mutationOpts,
    plan func(ctx context.Context, application *app.App, state *modState) (P, error),
    isEmpty func(P) bool,
    show func(p *printer, plan P),
    execute func(ctx context.Context, application *app.App, state *modState, plan P) error,
) error
```

Adopted by install, uninstall, enable, disable, update, and sync. sync's
extra outputs (mod-settings.dat, package deletions) happen inside its
`execute`. Read-only commands (list, check, search, show, download, …) are
out of scope. If a command's flow genuinely does not fit (e.g. a
conditional save), fitting it in by force is not required — adopt the
helper only where it simplifies.

## Testing

- New unit tests for `internal/resolver` using a Portal mock (reshape
  `portal_mock_test.go` for reuse or add a mock in the resolver package).
- Existing cli tests and e2e cases stay; only expectations covered by the
  intentional behavior changes (latest resolution, expansion skipping) are
  updated, with the reason stated in the PR.
- Every PR passes `mise run default`.

## Delivery plan

Four sequential PRs, each independently reviewable:

1. **PR1 — release selection**: create `internal/resolver` with the Select
   functions; migrate all commands; delete the four cli selection helpers.
   Closes #180.
2. **PR2 — resolution engine**: add `Resolver.Resolve`; migrate install,
   sync, download; delete the two BFS implementations and `builtinMODs`.
3. **PR3 — planning traversal**: unify the three BFS loops in
   `internal/dependency/plan.go`. Pure refactor.
4. **PR4 — mutation helpers + skeleton**: `InstalledMOD.Remove`, `MODList`
   helpers, `runMODMutation`; migrate the six mutation commands.

GitHub tracking: one epic issue with a task list; #180 covers PR1; three
new issues cover PR2-PR4.
