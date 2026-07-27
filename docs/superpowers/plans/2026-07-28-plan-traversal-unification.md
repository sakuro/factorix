# Planning BFS Traversal Unification Implementation Plan (PR3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reimplement `PlanEnable`, `MarkDisabledDependenciesForEnable`, and `PlanDisable` in `internal/dependency/plan.go` on top of one shared breadth-first traversal helper. Pure refactor: public API and behavior are unchanged. Closes #182.

**Architecture:** Add an unexported `walkBFS(seeds []mod.MOD, visited func(mod.MOD) bool, visit func(mod.MOD) ([]mod.MOD, error)) error` that owns the queue/dequeue loop. Each of the three functions supplies its own `visited` predicate and `visit` closure — which is where its edge-direction, edge-type filtering, error conditions, and side effects (marking a "planned" list, calling `SetNodeOperation`) already lived — and calls `walkBFS` instead of hand-rolling the loop. `visit` is responsible for its own dedup bookkeeping (updating the `planned`/`processed` map it closes over) before returning the next MODs to enqueue; `walkBFS` itself holds no state.

**Tech Stack:** Go, testify, `mise run test` for verification.

This is PR3 of the plan in
`docs/superpowers/specs/2026-07-27-dependency-resolution-unification-design.md`.

## Global Constraints

- Commit messages: English, `:emoji:` prefix. No AI attribution, no trailers.
- Code comments: English.
- This is a **pure refactor**: `internal/dependency/plan.go`'s three exported functions (`PlanEnable`, `MarkDisabledDependenciesForEnable`, `PlanDisable`) keep their exact signatures and behavior. Every existing test in `internal/dependency/plan_test.go` must pass **unmodified** — do not edit that file except to add the `"errors"` import needed by the new `walkBFS` test (Task 1).
- No CHANGELOG entry: this PR has no user-visible effect.
- Every task ends with `go test ./internal/dependency/` green; the branch ends with `mise run default` green.
- **Every implementer must confirm its working directory and branch before making any change** (see each task's Step 1/first step) — a prior attempt at this plan had a subagent's commit land in the wrong git checkout, requiring manual recovery.

---

### Task 1: `walkBFS` helper

**Files:**
- Modify: `internal/dependency/plan.go` (add `walkBFS` near the top, after the `var (...)` error block)
- Modify: `internal/dependency/plan_test.go` (add `"errors"` to imports; append `TestWalkBFS`)

**Interfaces:**
- Produces (Tasks 2-4 rely on this exact signature): `func walkBFS(seeds []mod.MOD, visited func(mod.MOD) bool, visit func(mod.MOD) ([]mod.MOD, error)) error`. Contract: pops from a FIFO queue seeded with `seeds`; for each popped MOD, if `visited` returns true it is skipped (no `visit` call); otherwise `visit` runs, and on success its returned MODs are appended to the queue — `visit` must update whatever state `visited` reads, since `walkBFS` tracks no visited state of its own; a non-nil error from `visit` aborts the walk immediately, propagated as `walkBFS`'s return value; nodes may appear in the queue multiple times (e.g., two parents enqueuing the same child) — `visited` filters the duplicate at pop time, so callers do not need to pre-filter before returning the next slice.

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: `/home/sakuro/github.com/sakuro/factorix/.claude/worktrees/plan-traversal` and `refactor/plan-traversal`. Do not proceed if either does not match.

- [ ] **Step 1: Confirm the baseline**

Run: `go test ./internal/dependency/...`
Expected: PASS (all existing tests green before any change).

- [ ] **Step 2: Write the failing test**

Add `"errors"` to `internal/dependency/plan_test.go`'s import block (alongside `"testing"`), then append:

```go
func TestWalkBFS(t *testing.T) {
	t.Run("visits each node once and follows returned neighbors breadth-first", func(t *testing.T) {
		adjacency := map[string][]string{"a": {"b", "c"}, "b": {"d"}, "c": {"d"}}
		seen := map[string]bool{}
		var order []string
		visited := func(m mod.MOD) bool { return seen[m.Name] }
		visit := func(m mod.MOD) ([]mod.MOD, error) {
			seen[m.Name] = true
			order = append(order, m.Name)
			var next []mod.MOD
			for _, n := range adjacency[m.Name] {
				next = append(next, testMOD(n))
			}
			return next, nil
		}

		err := walkBFS([]mod.MOD{testMOD("a")}, visited, visit)
		require.NoError(t, err)
		assert.Equal(t, []string{"a", "b", "c", "d"}, order) // d has two parents, visited once
	})

	t.Run("skips seeds visited already", func(t *testing.T) {
		visited := func(m mod.MOD) bool { return m.Name == "skip" }
		var seen []string
		visit := func(m mod.MOD) ([]mod.MOD, error) {
			seen = append(seen, m.Name)
			return nil, nil
		}

		err := walkBFS([]mod.MOD{testMOD("skip"), testMOD("go")}, visited, visit)
		require.NoError(t, err)
		assert.Equal(t, []string{"go"}, seen)
	})

	t.Run("aborts on error without visiting further nodes", func(t *testing.T) {
		boom := errors.New("boom")
		visited := func(mod.MOD) bool { return false }
		var seen []string
		visit := func(m mod.MOD) ([]mod.MOD, error) {
			seen = append(seen, m.Name)
			if m.Name == "a" {
				return nil, boom
			}
			return []mod.MOD{testMOD("unreachable")}, nil
		}

		err := walkBFS([]mod.MOD{testMOD("a")}, visited, visit)
		require.ErrorIs(t, err, boom)
		assert.Equal(t, []string{"a"}, seen)
	})
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `go test ./internal/dependency/ -run TestWalkBFS`
Expected: FAIL to build (`walkBFS` undefined).

- [ ] **Step 4: Implement `walkBFS`**

In `internal/dependency/plan.go`, insert after the `var (ErrDependencyMissing = ...)` block and before `PlanEnable`:

```go
// walkBFS performs a breadth-first traversal seeded by seeds. A popped MOD
// for which visited returns true is skipped without calling visit;
// otherwise visit runs and its returned MODs are appended to the queue.
// visit is responsible for updating whatever state visited reads — walkBFS
// tracks no visited state of its own, so a MOD reached through two
// different edges is deduplicated by visited at the second pop, not by
// walkBFS itself. A non-nil error from visit aborts the walk immediately.
func walkBFS(seeds []mod.MOD, visited func(mod.MOD) bool, visit func(mod.MOD) ([]mod.MOD, error)) error {
	queue := append([]mod.MOD(nil), seeds...)
	for len(queue) > 0 {
		m := queue[0]
		queue = queue[1:]
		if visited(m) {
			continue
		}
		next, err := visit(m)
		if err != nil {
			return err
		}
		queue = append(queue, next...)
	}
	return nil
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `go test ./internal/dependency/ -run TestWalkBFS -v`
Expected: PASS, all three subtests.

- [ ] **Step 6: Run the full package suite and lint**

Run: `go test ./internal/dependency/... && go vet ./internal/dependency/... && mise run lint`
Expected: all green. (`walkBFS` is unused by any exported function yet — `go vet`/`golangci-lint` will not flag this since it's referenced by `TestWalkBFS`.)

- [ ] **Step 7: Commit**

```bash
git add internal/dependency/plan.go internal/dependency/plan_test.go
git commit -m ":sparkles: Add walkBFS traversal helper"
```

- [ ] **Step 8: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Expected: the new commit's subject line, and `refactor/plan-traversal`. Report both in your final output.

---

### Task 2: Migrate `PlanEnable`

**Files:**
- Modify: `internal/dependency/plan.go`

**Interfaces:**
- Consumes: `walkBFS` from Task 1.
- No change to `PlanEnable`'s signature or behavior.

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: `/home/sakuro/github.com/sakuro/factorix/.claude/worktrees/plan-traversal` and `refactor/plan-traversal`. Do not proceed if either does not match. Then run `git log --oneline -1` and confirm the tip is Task 1's `walkBFS` commit.

- [ ] **Step 1: Confirm the baseline**

Run: `go test ./internal/dependency/ -run TestPlanEnable -v`
Expected: PASS (8 subtests: `TestPlanEnablePullsInRequiredDeps`, `TestPlanEnableSkipsAlreadyEnabled`, `TestPlanEnableMissingDependency`, `TestPlanEnableVersionMismatch`, `TestPlanEnablePullsInInstalledRecommendedDeps`, `TestPlanEnableSkipsUninstalledRecommendedDep`, `TestPlanEnableSkipsVersionMismatchedRecommendedDep`, `TestPlanEnableIgnoresRecommendedDepsWhenExcluded`).

- [ ] **Step 2: Replace the implementation**

Replace the body of `PlanEnable` in `internal/dependency/plan.go` (keep the doc comment above it unchanged) with:

```go
func PlanEnable(g *Graph, targets []mod.MOD, includeRecommended bool) ([]mod.MOD, error) {
	planned := map[mod.MOD]bool{}
	var order []mod.MOD

	visited := func(m mod.MOD) bool {
		node, ok := g.Node(m)
		return !ok || node.Enabled || planned[m]
	}
	visit := func(m mod.MOD) ([]mod.MOD, error) {
		planned[m] = true
		order = append(order, m)

		var next []mod.MOD
		for _, edge := range g.EdgesFrom(m) {
			if edge.To.IsBase() {
				continue
			}
			if edge.Type == TypeRecommended && !includeRecommended {
				continue
			}
			switch edge.Type {
			case TypeRequired:
				depNode, ok := g.Node(edge.To)
				if !ok {
					return nil, fmt.Errorf("%w: MOD '%s' requires '%s' which is not installed", ErrDependencyMissing, m, edge.To)
				}
				if !edge.SatisfiedBy(depNode.Version) {
					return nil, fmt.Errorf("%w: cannot enable %s: dependency %s version requirement not satisfied (required: %s, installed: %s)",
						ErrDependencyVersion, m, edge.To, edge.Requirement, depNode.Version)
				}
				if !depNode.Enabled && !planned[edge.To] {
					next = append(next, edge.To)
				}
			case TypeRecommended:
				depNode, ok := g.Node(edge.To)
				if !ok || !edge.SatisfiedBy(depNode.Version) {
					continue
				}
				if !depNode.Enabled && !planned[edge.To] {
					next = append(next, edge.To)
				}
			}
		}
		return next, nil
	}

	if err := walkBFS(targets, visited, visit); err != nil {
		return nil, err
	}
	return order, nil
}
```

- [ ] **Step 3: Run the same tests to verify they still pass, unmodified**

Run: `go test ./internal/dependency/ -run TestPlanEnable -v`
Expected: PASS, same 8 subtests as Step 1, `plan_test.go` untouched.

- [ ] **Step 4: Run the full package suite**

Run: `go test ./internal/dependency/... && go vet ./internal/dependency/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/dependency/plan.go
git commit -m ":recycle: Migrate PlanEnable onto walkBFS"
```

- [ ] **Step 6: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Expected: this commit's subject line, and `refactor/plan-traversal`. Report both in your final output.

---

### Task 3: Migrate `MarkDisabledDependenciesForEnable`

**Files:**
- Modify: `internal/dependency/plan.go`

**Interfaces:**
- Consumes: `walkBFS` from Task 1.
- No change to `MarkDisabledDependenciesForEnable`'s signature or behavior.

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: `/home/sakuro/github.com/sakuro/factorix/.claude/worktrees/plan-traversal` and `refactor/plan-traversal`. Do not proceed if either does not match. Then run `git log --oneline -1` and confirm the tip is Task 2's `PlanEnable` migration commit.

- [ ] **Step 1: Confirm the baseline**

Run: `go test ./internal/dependency/ -run TestMarkDisabledDependenciesForEnable -v`
Expected: PASS (3 subtests: `TestMarkDisabledDependenciesForEnable`, `TestMarkDisabledDependenciesForEnableRecommended`, `TestMarkDisabledDependenciesForEnableIgnoresRecommendedWhenExcluded`).

- [ ] **Step 2: Replace the implementation**

Replace the body of `MarkDisabledDependenciesForEnable` with:

```go
func MarkDisabledDependenciesForEnable(g *Graph, includeRecommended bool) {
	var seeds []mod.MOD
	for _, node := range g.Nodes() {
		if node.Operation == OpInstall || node.Operation == OpEnable {
			seeds = append(seeds, node.MOD)
		}
	}

	processed := map[mod.MOD]bool{}
	visited := func(m mod.MOD) bool { return processed[m] }
	visit := func(m mod.MOD) ([]mod.MOD, error) {
		processed[m] = true

		var next []mod.MOD
		for _, edge := range g.EdgesFrom(m) {
			relevant := edge.Type == TypeRequired || (includeRecommended && edge.Type == TypeRecommended)
			if !relevant {
				continue
			}
			depNode, ok := g.Node(edge.To)
			if !ok || depNode.Operation != OpNone || depNode.Enabled || !depNode.Installed {
				continue
			}
			g.SetNodeOperation(edge.To, OpEnable)
			next = append(next, edge.To)
		}
		return next, nil
	}

	_ = walkBFS(seeds, visited, visit)
}
```

- [ ] **Step 3: Run the same tests to verify they still pass, unmodified**

Run: `go test ./internal/dependency/ -run TestMarkDisabledDependenciesForEnable -v`
Expected: PASS, same 3 subtests as Step 1.

- [ ] **Step 4: Run the full package suite**

Run: `go test ./internal/dependency/... && go vet ./internal/dependency/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/dependency/plan.go
git commit -m ":recycle: Migrate MarkDisabledDependenciesForEnable onto walkBFS"
```

- [ ] **Step 6: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Expected: this commit's subject line, and `refactor/plan-traversal`. Report both in your final output.

---

### Task 4: Migrate `PlanDisable`

**Files:**
- Modify: `internal/dependency/plan.go`

**Interfaces:**
- Consumes: `walkBFS` from Task 1.
- No change to `PlanDisable`'s signature or behavior.

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: `/home/sakuro/github.com/sakuro/factorix/.claude/worktrees/plan-traversal` and `refactor/plan-traversal`. Do not proceed if either does not match. Then run `git log --oneline -1` and confirm the tip is Task 3's `MarkDisabledDependenciesForEnable` migration commit.

- [ ] **Step 1: Confirm the baseline**

Run: `go test ./internal/dependency/ -run TestPlanDisable -v`
Expected: PASS (3 subtests: `TestPlanDisableAll`, `TestPlanDisablePullsInDependents`, `TestPlanDisableSkipsNotInstalledOrAlreadyDisabled`; note `TestPlanDisableAll` covers `PlanDisableAll`, a separate function this task does not touch — it stays as-is).

- [ ] **Step 2: Replace the implementation**

Replace the body of `PlanDisable` (leave `PlanDisableAll` above it untouched) with:

```go
func PlanDisable(g *Graph, targets []mod.MOD) []mod.MOD {
	planned := map[mod.MOD]bool{}
	var order []mod.MOD

	visited := func(m mod.MOD) bool {
		node, ok := g.Node(m)
		return !ok || !node.Enabled || planned[m]
	}
	visit := func(m mod.MOD) ([]mod.MOD, error) {
		next := g.FindEnabledDependents(m)
		planned[m] = true
		order = append(order, m)
		return next, nil
	}

	_ = walkBFS(targets, visited, visit)
	return order
}
```

Note: the original pre-filtered `next` to exclude already-planned dependents before enqueueing; that pre-filter is dropped here because `visited` re-filters at pop time and produces the identical `order` (verified: a duplicate entry in the queue is a no-op when popped, since `visited` will already be true for it).

- [ ] **Step 3: Run the same tests to verify they still pass, unmodified**

Run: `go test ./internal/dependency/ -run TestPlanDisable -v`
Expected: PASS, same 3 subtests as Step 1.

- [ ] **Step 4: Run the full package suite**

Run: `go test ./internal/dependency/... && go vet ./internal/dependency/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/dependency/plan.go
git commit -m ":recycle: Migrate PlanDisable onto walkBFS"
```

- [ ] **Step 6: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Expected: this commit's subject line, and `refactor/plan-traversal`. Report both in your final output.

---

### Task 5: Full verification and pull request

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: `/home/sakuro/github.com/sakuro/factorix/.claude/worktrees/plan-traversal` and `refactor/plan-traversal`.

- [ ] **Step 1: Confirm `plan_test.go` is unmodified except the Task 1 addition**

Run: `git diff origin/main..HEAD -- internal/dependency/plan_test.go`
Expected: the only change is the `"errors"` import and the appended `TestWalkBFS` function from Task 1 — every pre-existing test function is untouched (no assertions edited).

- [ ] **Step 2: Run the full check suite**

Run: `mise run default`
Expected: PASS (test + e2e + vet + lint + fmt-check). The e2e suite exercises `mod install`/`enable`/`disable`/`sync` end-to-end and must still pass unchanged, since this task changes no observable behavior.

- [ ] **Step 3: Push and open the PR**

Push the branch and create the PR with the `create-pr` skill. Title: `:recycle: Unify planning BFS traversals in internal/dependency`. Body: summary (one shared `walkBFS` helper backs `PlanEnable`, `MarkDisabledDependenciesForEnable`, and `PlanDisable`; pure refactor, no behavior change, all pre-existing tests pass unmodified), `Closes #182`, `Related to #184`. No AI attribution.

- [ ] **Step 4: Verify CI is green and report the PR URL**
