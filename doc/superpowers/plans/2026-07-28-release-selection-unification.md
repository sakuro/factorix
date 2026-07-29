# Release Selection Unification Implementation Plan (PR1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `internal/resolver` with unified release-selection functions and migrate every command to them, closing #180.

**Architecture:** A new `internal/resolver` package (depending on `internal/api`, `internal/dependency`, `internal/mod`) owns the three selection rules. `internal/cli` keeps a thin `selectRelease(info, spec)` adapter for `modSpec` and loses its four ad-hoc helpers (`findRelease`, `findSyncRelease`, `findCompatibleRelease`, `latestByReleaseDate`).

**Tech Stack:** Go, testify (assert/require), `mise run default` for verification.

This is PR1 of the four-PR plan in
`docs/superpowers/specs/2026-07-27-dependency-resolution-unification-design.md`.
PR2-PR4 get their own plan documents later.

## Global Constraints

- Commit messages: English, `:emoji:` prefix (e.g. `:recycle:` refactor, `:sparkles:` feature, `:white_check_mark:` tests). No AI attribution, no `Claude-Session` trailers.
- Code comments and doc comments: English. "MOD" is uppercase in exported identifiers and user-facing text.
- Every task ends with `mise run test` green; the branch ends with `mise run default` green.
- Unified "latest" rule (decided in #180): `info.LatestRelease` when present, otherwise the highest version by `mod.MODVersion.Compare`. The live `/full` endpoint always returns `latest_release: null`, so in practice the highest version wins; the field is honored for future-proofing and short-endpoint consumers.

---

### Task 1: `internal/resolver` package with selection functions

**Files:**
- Create: `internal/resolver/select.go`
- Create: `internal/resolver/select_test.go`

**Interfaces:**
- Consumes: `api.MODInfo`, `api.Release`, `mod.MODVersion`, `dependency.VersionRequirement` (all existing).
- Produces: `resolver.SelectLatest(info *api.MODInfo) *api.Release`, `resolver.SelectExact(info *api.MODInfo, version mod.MODVersion) *api.Release`, `resolver.SelectCompatible(info *api.MODInfo, requirement *dependency.VersionRequirement) *api.Release`. Task 2 calls all three.

- [ ] **Step 1: Create the feature branch**

```bash
git checkout -b refactor/release-selection
```

- [ ] **Step 2: Write the failing tests**

Create `internal/resolver/select_test.go` (internal test package, matching `internal/dependency`):

```go
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
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `go test ./internal/resolver/`
Expected: FAIL to build (package `resolver` does not exist yet).

- [ ] **Step 4: Implement `select.go`**

Create `internal/resolver/select.go`:

```go
// Package resolver selects MOD Portal releases and (in later stages)
// resolves MOD dependencies against the Portal. It is the single place
// where "latest" is defined for every command.
package resolver

import (
	"slices"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

// SelectLatest returns the MOD's latest release: the Portal's
// latest_release field when present, otherwise the highest version among
// Releases. The full endpoint is known to always omit latest_release, so
// the fallback is the common path (#180). Returns nil when the MOD has no
// releases.
func SelectLatest(info *api.MODInfo) *api.Release {
	if info.LatestRelease != nil {
		return info.LatestRelease
	}
	return highestVersion(info.Releases)
}

// SelectExact returns the release with exactly the given version, or nil.
func SelectExact(info *api.MODInfo, version mod.MODVersion) *api.Release {
	for i := range info.Releases {
		if info.Releases[i].Version == version {
			return &info.Releases[i]
		}
	}
	return nil
}

// SelectCompatible returns the latest release satisfying the requirement:
// with a nil requirement it is SelectLatest; otherwise latest_release when
// that satisfies the requirement, else the highest satisfying version.
// Returns nil when no release satisfies.
func SelectCompatible(info *api.MODInfo, requirement *dependency.VersionRequirement) *api.Release {
	if requirement == nil {
		return SelectLatest(info)
	}
	if info.LatestRelease != nil && requirement.SatisfiedBy(info.LatestRelease.Version) {
		return info.LatestRelease
	}
	var compatible []api.Release
	for _, r := range info.Releases {
		if requirement.SatisfiedBy(r.Version) {
			compatible = append(compatible, r)
		}
	}
	return highestVersion(compatible)
}

func highestVersion(releases []api.Release) *api.Release {
	if len(releases) == 0 {
		return nil
	}
	highest := slices.MaxFunc(releases, func(a, b api.Release) int {
		return a.Version.Compare(b.Version)
	})
	return &highest
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `go test ./internal/resolver/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/resolver
git commit -m ":sparkles: Add internal/resolver with unified release selection"
```

---

### Task 2: Migrate cli to the resolver selection functions

**Files:**
- Modify: `internal/cli/download_support.go` (replace `findRelease`, `findCompatibleRelease`, `latestByReleaseDate` with a `selectRelease` adapter)
- Modify: `internal/cli/mod_install.go` (two call sites)
- Modify: `internal/cli/mod_download.go` (two call sites)
- Modify: `internal/cli/mod_sync.go` (delete `findSyncRelease`, one call site)
- Modify: `internal/cli/mod_update.go` (one call site)
- Modify: `internal/cli/download_support_test.go` (delete `TestFindRelease`, `TestFindCompatibleRelease`)
- Modify: `internal/cli/mod_sync_test.go` (delete the `findSyncRelease` test block around lines 220-233)

**Interfaces:**
- Consumes: `resolver.SelectLatest`, `resolver.SelectExact`, `resolver.SelectCompatible` from Task 1.
- Produces: `selectRelease(info *api.MODInfo, spec modSpec) *api.Release` in `download_support.go`, used by install, download, and sync.

- [ ] **Step 1: Replace the helpers in `download_support.go`**

Delete `findRelease`, `findCompatibleRelease`, and `latestByReleaseDate` (lines 43-88) and add in their place (import `github.com/sakuro/factorix/internal/resolver`):

```go
// selectRelease resolves a modSpec to a release: the unified latest rule
// (resolver.SelectLatest) for "latest" specs, the exact version otherwise.
func selectRelease(info *api.MODInfo, spec modSpec) *api.Release {
	if spec.Latest {
		return resolver.SelectLatest(info)
	}
	return resolver.SelectExact(info, spec.Version)
}
```

- [ ] **Step 2: Update the call sites**

- `mod_install.go` `planInstall`: `findRelease(info, spec)` → `selectRelease(info, spec)`.
- `mod_install.go` `resolveInstallDependencies`: `findCompatibleRelease(info, requirement)` → `resolver.SelectCompatible(info, requirement)`.
- `mod_download.go` `planDownload`: `findRelease(info, spec)` → `selectRelease(info, spec)`.
- `mod_download.go` `resolveDownloadDependencies`: `findCompatibleRelease(info, newDeps[i].requirement)` → `resolver.SelectCompatible(info, newDeps[i].requirement)`.
- `mod_sync.go` `planSyncInstallation`: `findSyncRelease(info, spec)` → `selectRelease(info, spec)`; delete the `findSyncRelease` function and its Ruby-inconsistency comment (the inconsistency no longer exists).
- `mod_update.go` `findUpdateTargets`: `latest := latestByReleaseDate(info.Releases)` → `latest := resolver.SelectLatest(info)`.

Add the `resolver` import to each file that now references it.

- [ ] **Step 3: Delete the superseded tests**

- `download_support_test.go`: delete `TestFindRelease` and `TestFindCompatibleRelease` (their behavior is covered by `internal/resolver/select_test.go`). Keep the `release` helper if other tests use it; delete it too if unused.
- `mod_sync_test.go`: delete the `findSyncRelease` assertions (the block testing exact version, missing version, latest fallback, and `LatestRelease` preference).

- [ ] **Step 4: Build and run the package tests**

Run: `go build ./... && go test ./internal/cli/ ./internal/resolver/`
Expected: build PASS. Test failures are acceptable only in integration tests whose fixtures distinguish date-based from version-based "latest" — collect the list for Step 5. Anything else must be fixed before proceeding.

- [ ] **Step 5: Reconcile integration-test expectations**

The mock Portal (`portal_mock_test.go`) mirrors the live API: `/full` never carries `latest_release`, and releases default to the same `ReleasedAt`. Two semantic shifts can surface:

1. Fixtures where the newest-by-date release is not the highest version: "latest" now selects the highest version.
2. Fixtures with equal dates and unordered releases: the old code picked the first listed release; the new code deterministically picks the highest version.

For each failing test in `portal_integration_test.go`, `portal_integration_download_test.go`, `portal_integration_update_test.go`, `portal_integration_sync_test.go`, `mod_install_update_test.go`, or `download_test.go`: confirm the failure is one of these two shifts, then update the expected version/filename. A failure that does not match either shift is a regression — stop and fix the code instead. Also update `portal_integration_sync_test.go`'s comment referencing `findSyncRelease` (line 19) to reference the unified rule.

- [ ] **Step 6: Run the full check suite**

Run: `mise run default`
Expected: PASS (test + e2e + vet + lint + fmt-check).

- [ ] **Step 7: Commit**

```bash
git add internal/cli
git commit -m ":recycle: Unify release selection on internal/resolver"
```

---

### Task 3: Pull request

- [ ] **Step 1: Push and open the PR**

Push the branch and create the PR with the `create-pr` skill. Title: `Unify release selection into internal/resolver`. Body must include:

- Summary: single definition of "latest" (`latest_release` when present, else highest version); replaces the four cli helpers.
- Behavior change note: install/download/update "latest" moves from newest-by-release-date to the unified rule; sync is unchanged.
- `Closes #180`, and a reference to epic #184.
- No AI attribution.

- [ ] **Step 2: Verify CI is green and report the PR URL**
