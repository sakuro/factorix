# mod-list Mutation Helpers and Command Skeleton Unification Implementation Plan (PR4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `mod.InstalledMOD.Remove()`, `mod.MODList.EnsureEnabled()`, and `mod.MODList.Replace()` to remove duplicated package-deletion and mod-list-mutation logic, and add a generic `runMODMutation[P any]` command skeleton in `internal/cli` that replaces the repeated RequireGameStopped → loadMODState → plan → confirm → execute → backup+save sequence. Closes #183.

**Architecture:** Two small, independently useful additions to `internal/mod` (Task 1-2), then a generic skeleton function in `internal/cli` proven first on the two simplest commands (Task 3), then rolled out to install (Task 4), uninstall (Task 5), and update (Task 6). `mod sync` is **excluded** from the skeleton — its pre-plan save-file loading, conditional mod-list.json save, and second persistence target (mod-settings.dat) do not fit `runMODMutation`'s fixed shape without contorting it (per the design spec's own escape hatch: "adopt only where it simplifies"). Sync still benefits from `InstalledMOD.Remove()` and `MODList.Replace()` internally (Task 7).

**Tech Stack:** Go, testify, `mise run test` / `mise run e2e` for verification.

This is PR4 of the plan in
`docs/superpowers/specs/2026-07-27-dependency-resolution-unification-design.md`.

## Global Constraints

- Commit messages: English, `:emoji:` prefix. No AI attribution, no trailers.
- Code comments: English. "MOD" uppercase in exported identifiers and user-facing text.
- Every user-visible message (Info/Success/Warn text) must stay **exactly** as it is today unless a task explicitly says otherwise — this PR restructures internals, not UX. Where a task changes a message, it says so.
- `mod.MODList.Replace(m, state)` must **not** be called with an expansion MOD — it forwards `Remove`'s `ErrCannotRemoveExpansionMOD` rejection (see Task 2). Callers with an expansion carve-out (sync's `syncEnable`) keep that carve-out.
- `mise run default` must pass at the end of every task that touches `internal/cli` (it exercises the e2e suite, which is the closest thing to a message-regression net for this PR).
- No CHANGELOG entry unless a task says otherwise — this PR does not intend a user-visible behavior change; if `mise run default`'s e2e suite catches an accidental message change, fix the code to match the old message rather than updating an e2e fixture, unless the task explicitly sanctions the change.

---

### Task 1: `mod.InstalledMOD.Remove()`

**Files:**
- Modify: `internal/mod/installed_mod.go` (add `Remove`)
- Modify: `internal/mod/installed_mod_test.go` (add `TestInstalledMODRemove`)

**Interfaces:**
- Produces (Task 5, 7 rely on this): `func (im InstalledMOD) Remove() error` — deletes the package at `im.Path`: `os.RemoveAll` when `im.Form == FormDirectory`, `os.Remove` otherwise.

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: `/home/sakuro/github.com/sakuro/factorix/.claude/worktrees/mutation-skeleton` and `refactor/mutation-skeleton`. Do not proceed otherwise.

- [ ] **Step 1: Confirm the baseline**

Run: `go test ./internal/mod/...`
Expected: PASS.

- [ ] **Step 2: Write the failing test**

Append to `internal/mod/installed_mod_test.go` (`"os"` and `"path/filepath"` are already imported):

```go
func TestInstalledMODRemove(t *testing.T) {
	t.Run("removes a zip file", func(t *testing.T) {
		dir := t.TempDir()
		path := filepath.Join(dir, "some-mod_1.0.0.zip")
		require.NoError(t, os.WriteFile(path, []byte("zip"), 0o644))
		im := InstalledMOD{MOD: MOD{Name: "some-mod"}, Form: FormZIP, Path: path}

		require.NoError(t, im.Remove())
		_, err := os.Stat(path)
		require.ErrorIs(t, err, os.ErrNotExist)
	})

	t.Run("removes a directory recursively", func(t *testing.T) {
		dir := t.TempDir()
		path := filepath.Join(dir, "some-mod")
		require.NoError(t, os.Mkdir(path, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(path, "info.json"), []byte("{}"), 0o644))
		im := InstalledMOD{MOD: MOD{Name: "some-mod"}, Form: FormDirectory, Path: path}

		require.NoError(t, im.Remove())
		_, err := os.Stat(path)
		require.ErrorIs(t, err, os.ErrNotExist)
	})
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `go test ./internal/mod/ -run TestInstalledMODRemove`
Expected: FAIL to build (`Remove` undefined on `InstalledMOD`).

- [ ] **Step 4: Implement `Remove`**

In `internal/mod/installed_mod.go`, add after `formPriority`:

```go
// Remove deletes the package from disk: the whole directory when Form is
// FormDirectory, the single file otherwise.
func (im InstalledMOD) Remove() error {
	if im.Form == FormDirectory {
		return os.RemoveAll(im.Path)
	}
	return os.Remove(im.Path)
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `go test ./internal/mod/ -run TestInstalledMODRemove -v`
Expected: PASS, both subtests.

- [ ] **Step 6: Run the full package suite**

Run: `go test ./internal/mod/... && go vet ./internal/mod/... && mise run lint`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add internal/mod/installed_mod.go internal/mod/installed_mod_test.go
git commit -m ":sparkles: Add InstalledMOD.Remove"
```

- [ ] **Step 8: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Report both in your final output.

---

### Task 2: `mod.MODList.EnsureEnabled()` and `mod.MODList.Replace()`

**Files:**
- Modify: `internal/mod/mod_list.go` (add `EnsureEnabled`, `Replace`)
- Modify: `internal/mod/mod_list_test.go` (add `TestMODListEnsureEnabled`, `TestMODListReplace`)

**Interfaces:**
- Produces (Tasks 3-4, 6-7 rely on these):
  - `func (l *MODList) EnsureEnabled(m MOD) (added bool, err error)` — if `m` is absent, `Add(m, MODState{Enabled: true})` and return `added=true`; if present and not enabled, `Enable(m)` and return `added=false`; if present and already enabled, no-op and return `added=false`. Errors from `Add`/`Enable` propagate (e.g. attempting this on a state that would violate `Add`'s base-MOD guard, though in practice `EnsureEnabled` never disables anything so that guard never fires here).
  - `func (l *MODList) Replace(m MOD, state MODState) error` — `Remove(m)` (no-op if absent) then `Add(m, state)`. Inherits `Remove`'s rejection of base and expansion MODs — **must not be called with an expansion MOD** (it would return `ErrCannotRemoveExpansionMOD`).

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: `/home/sakuro/github.com/sakuro/factorix/.claude/worktrees/mutation-skeleton` and `refactor/mutation-skeleton`. Then `git log --oneline -1` and confirm the tip is Task 1's commit.

- [ ] **Step 1: Confirm the baseline**

Run: `go test ./internal/mod/...`
Expected: PASS.

- [ ] **Step 2: Write the failing tests**

Append to `internal/mod/mod_list_test.go`:

```go
func TestMODListEnsureEnabled(t *testing.T) {
	list := NewMODList()
	require.NoError(t, list.Add(MOD{Name: "base"}, MODState{Enabled: true}))

	t.Run("adds an absent MOD as enabled", func(t *testing.T) {
		added, err := list.EnsureEnabled(MOD{Name: "new-mod"})
		require.NoError(t, err)
		assert.True(t, added)
		enabled, err := list.Enabled(MOD{Name: "new-mod"})
		require.NoError(t, err)
		assert.True(t, enabled)
	})

	t.Run("enables a present-but-disabled MOD", func(t *testing.T) {
		require.NoError(t, list.Add(MOD{Name: "disabled-mod"}, MODState{Enabled: false}))
		added, err := list.EnsureEnabled(MOD{Name: "disabled-mod"})
		require.NoError(t, err)
		assert.False(t, added)
		enabled, err := list.Enabled(MOD{Name: "disabled-mod"})
		require.NoError(t, err)
		assert.True(t, enabled)
	})

	t.Run("no-ops on an already-enabled MOD", func(t *testing.T) {
		require.NoError(t, list.Add(MOD{Name: "enabled-mod"}, MODState{Enabled: true}))
		added, err := list.EnsureEnabled(MOD{Name: "enabled-mod"})
		require.NoError(t, err)
		assert.False(t, added)
	})
}

func TestMODListReplace(t *testing.T) {
	version1 := MODVersion{Major: 1}
	version2 := MODVersion{Major: 2}

	t.Run("changes state and version of a present MOD", func(t *testing.T) {
		list := NewMODList()
		require.NoError(t, list.Add(MOD{Name: "some-mod"}, MODState{Enabled: false, Version: &version1}))

		require.NoError(t, list.Replace(MOD{Name: "some-mod"}, MODState{Enabled: true, Version: &version2}))

		enabled, err := list.Enabled(MOD{Name: "some-mod"})
		require.NoError(t, err)
		assert.True(t, enabled)
		got, err := list.Version(MOD{Name: "some-mod"})
		require.NoError(t, err)
		require.NotNil(t, got)
		assert.Equal(t, version2, *got)
	})

	t.Run("adds an absent MOD", func(t *testing.T) {
		list := NewMODList()
		require.NoError(t, list.Replace(MOD{Name: "new-mod"}, MODState{Enabled: true}))
		assert.True(t, list.Contains(MOD{Name: "new-mod"}))
	})

	t.Run("rejects an expansion MOD", func(t *testing.T) {
		list := NewMODList()
		require.NoError(t, list.Add(MOD{Name: "space-age"}, MODState{Enabled: true}))
		err := list.Replace(MOD{Name: "space-age"}, MODState{Enabled: true, Version: &version2})
		require.ErrorIs(t, err, ErrCannotRemoveExpansionMOD)
	})

	t.Run("preserves insertion order", func(t *testing.T) {
		list := NewMODList()
		require.NoError(t, list.Add(MOD{Name: "first"}, MODState{Enabled: true}))
		require.NoError(t, list.Add(MOD{Name: "second"}, MODState{Enabled: true}))
		require.NoError(t, list.Replace(MOD{Name: "first"}, MODState{Enabled: true, Version: &version1}))
		assert.Equal(t, []MOD{{Name: "first"}, {Name: "second"}}, slices.Collect(list.MODs()))
	})
}
```

Add `"slices"` to the test file's imports if not already present (check the existing import block first).

- [ ] **Step 3: Run the tests to verify they fail**

Run: `go test ./internal/mod/ -run 'TestMODListEnsureEnabled|TestMODListReplace'`
Expected: FAIL to build (`EnsureEnabled`, `Replace` undefined).

- [ ] **Step 4: Implement `EnsureEnabled` and `Replace`**

In `internal/mod/mod_list.go`, add after `Disable`:

```go
// EnsureEnabled makes sure m is present and enabled: an absent MOD is
// added as enabled (added=true); a present-but-disabled MOD is enabled in
// place (added=false); an already-enabled MOD is left untouched
// (added=false). Callers that need to distinguish "was already enabled"
// from "was enabled just now" should check Enabled(m) before calling.
func (l *MODList) EnsureEnabled(m MOD) (added bool, err error) {
	if !l.Contains(m) {
		if err := l.Add(m, MODState{Enabled: true}); err != nil {
			return false, err
		}
		return true, nil
	}
	if enabled, err := l.Enabled(m); err != nil {
		return false, err
	} else if !enabled {
		return false, l.Enable(m)
	}
	return false, nil
}

// Replace changes an entry's recorded state (typically its version)
// atomically: Remove followed by Add. A no-op Remove when m is absent
// makes this equally usable to add a new entry. Remove rejects base and
// expansion MODs, so Replace does too — callers needing to touch those
// must use Enable/Disable directly.
func (l *MODList) Replace(m MOD, state MODState) error {
	if err := l.Remove(m); err != nil {
		return err
	}
	return l.Add(m, state)
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `go test ./internal/mod/ -run 'TestMODListEnsureEnabled|TestMODListReplace' -v`
Expected: PASS, all subtests.

- [ ] **Step 6: Run the full package suite**

Run: `go test ./internal/mod/... && go vet ./internal/mod/... && mise run lint`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add internal/mod/mod_list.go internal/mod/mod_list_test.go
git commit -m ":sparkles: Add MODList.EnsureEnabled and MODList.Replace"
```

- [ ] **Step 8: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Report both in your final output.

---

### Task 3: `runMODMutation` skeleton, proven on enable and disable

**Files:**
- Create: `internal/cli/mod_mutation.go` (the generic skeleton)
- Modify: `internal/cli/mod_enable.go` (adopt it; delete `applyMODListChange` usage)
- Modify: `internal/cli/mod_disable.go` (adopt it)
- Delete: `applyMODListChange` (currently in `mod_enable.go:82-107`) — folded into `runMODMutation`

**Interfaces:**
- Produces (Tasks 4-6 rely on this exact signature):

```go
type mutationOpts struct {
	yes             bool
	quiet           bool
	backupExtension string
	confirmPrompt   string
	emptyMessage    string
}

func runMODMutation[P any](
	cmd *cobra.Command, c *cli, opts mutationOpts,
	plan func(ctx context.Context, application *app.App, state *modState) (P, error),
	isEmpty func(P) bool,
	show func(p *printer, plan P),
	execute func(ctx context.Context, application *app.App, state *modState, p *printer, plan P) error,
) error
```

Sequence: `c.App()` → `RequireGameStopped()` → `loadMODState()` → `plan(...)` → if `isEmpty(planned)`: print `opts.emptyMessage`, return nil → `show(p, planned)` → `confirm(cmd, opts.quiet, opts.yes, opts.confirmPrompt)` → if not confirmed: return nil → `execute(...)` → backup + save `mod-list.json` → print `"Saved mod-list.json"`. Per-command summary messages (e.g. `"Enabled N MOD(s)"`) are the `execute` closure's responsibility, printed via the `p` it receives, since the count and wording differ per command.

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: `/home/sakuro/github.com/sakuro/factorix/.claude/worktrees/mutation-skeleton` and `refactor/mutation-skeleton`. Then `git log --oneline -1` and confirm the tip is Task 2's commit.

- [ ] **Step 1: Confirm the baseline**

Run: `mise run e2e`
Expected: PASS. (This is the regression net for the message-preservation constraint; run it before and after every task that touches `internal/cli`.)

- [ ] **Step 2: Create `mod_mutation.go`**

```go
package cli

import (
	"context"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
)

// mutationOpts configures runMODMutation's confirmation and persistence
// behavior; the strings and flags a command's own cobra flags feed in.
type mutationOpts struct {
	yes             bool
	quiet           bool
	backupExtension string
	confirmPrompt   string
	emptyMessage    string
}

// runMODMutation implements the shared skeleton behind the MOD-list
// mutation commands (install, uninstall, enable, disable, update):
// RequireGameStopped, load state, plan, bail out on an empty plan, show
// the plan, confirm, execute, then back up and save mod-list.json.
// execute is responsible for any command-specific summary message; this
// function only prints the final "Saved mod-list.json".
func runMODMutation[P any](
	cmd *cobra.Command, c *cli, opts mutationOpts,
	plan func(ctx context.Context, application *app.App, state *modState) (P, error),
	isEmpty func(P) bool,
	show func(p *printer, plan P),
	execute func(ctx context.Context, application *app.App, state *modState, p *printer, plan P) error,
) error {
	application, err := c.App()
	if err != nil {
		return err
	}
	if err := application.RequireGameStopped(); err != nil {
		return err
	}

	state, err := loadMODState(application)
	if err != nil {
		return err
	}

	planned, err := plan(cmd.Context(), application, state)
	if err != nil {
		return err
	}

	p := c.printer(cmd)
	if isEmpty(planned) {
		p.Info(opts.emptyMessage)
		return nil
	}

	show(p, planned)

	confirmed, err := confirm(cmd, opts.quiet, opts.yes, opts.confirmPrompt)
	if err != nil {
		return err
	}
	if !confirmed {
		return nil
	}

	if err := execute(cmd.Context(), application, state, p, planned); err != nil {
		return err
	}

	modListPath, err := application.Runtime.MODListPath()
	if err != nil {
		return err
	}
	if err := backupIfExists(modListPath, opts.backupExtension); err != nil {
		return err
	}
	if err := state.modList.Save(modListPath); err != nil {
		return err
	}
	p.Success("Saved mod-list.json")
	return nil
}
```

- [ ] **Step 3: Rewrite `mod_enable.go`**

Replace the whole file with:

```go
package cli

import (
	"context"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

func newMODEnableCommand(c *cli) *cobra.Command {
	var yes, ignoreRecommended bool
	var backupExtension string

	cmd := &cobra.Command{
		Use:   "enable <mod-name>...",
		Short: "Enable MOD(s) in mod-list.json (recursively enables dependencies)",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			opts := mutationOpts{
				yes:             yes,
				quiet:           c.quiet,
				backupExtension: backupExtension,
				confirmPrompt:   "Do you want to enable these MOD(s)?",
				emptyMessage:    "All specified MOD(s) are already enabled",
			}
			plan := func(ctx context.Context, application *app.App, state *modState) ([]mod.MOD, error) {
				targets := make([]mod.MOD, len(args))
				for i, name := range args {
					targets[i] = mod.MOD{Name: name}
				}
				for _, m := range targets {
					if !state.graph.Contains(m) {
						return nil, fmt.Errorf("MOD '%s' is not installed", m)
					}
				}

				planned, err := dependency.PlanEnable(state.graph, targets, !ignoreRecommended)
				if err != nil {
					return nil, err
				}
				if err := dependency.ValidateNoConflicts(state.graph, planned); err != nil {
					return nil, err
				}
				return planned, nil
			}
			isEmpty := func(planned []mod.MOD) bool { return len(planned) == 0 }
			show := func(p *printer, planned []mod.MOD) {
				p.Info(fmt.Sprintf("Planning to enable %d MOD(s):", len(planned)))
				for _, m := range planned {
					p.Say("  - " + m.String())
				}
			}
			execute := func(ctx context.Context, application *app.App, state *modState, p *printer, planned []mod.MOD) error {
				for _, m := range planned {
					if err := state.modList.Enable(m); err != nil {
						return err
					}
					p.Success("Enabled " + m.String())
				}
				p.Success(fmt.Sprintf("Enabled %d MOD(s)", len(planned)))
				return nil
			}
			return runMODMutation(cmd, c, opts, plan, isEmpty, show, execute)
		},
	}
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().BoolVar(&ignoreRecommended, "ignore-recommended", false, "Do not enable recommended dependencies")
	cmd.Flags().StringVar(&backupExtension, "backup-extension", defaultBackupExtension, "Backup file extension")
	return cmd
}
```

Note: `RequireGameStopped` now runs *after* `c.App()` inside `runMODMutation`, same relative order as before (the old code's comment about matching Ruby's ordering still holds — `App()` construction has no game-stopped check itself, so the check still happens immediately after app construction, just one call frame deeper). This is not a behavior change.

- [ ] **Step 4: Rewrite `mod_disable.go`**

Replace the whole file with:

```go
package cli

import (
	"context"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

func newMODDisableCommand(c *cli) *cobra.Command {
	var yes, all bool
	var backupExtension string

	cmd := &cobra.Command{
		Use:   "disable [mod-name]...",
		Short: "Disable MOD(s) in mod-list.json (recursively disables dependent MOD(s))",
		Args:  cobra.ArbitraryArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if all && len(args) > 0 {
				return fmt.Errorf("Cannot specify MOD names with --all option")
			}
			if !all && len(args) == 0 {
				return fmt.Errorf("Must specify MOD names or use --all option")
			}

			opts := mutationOpts{
				yes:             yes,
				quiet:           c.quiet,
				backupExtension: backupExtension,
				confirmPrompt:   "Do you want to disable these MOD(s)?",
				emptyMessage:    "All specified MOD(s) are already disabled",
			}
			plan := func(ctx context.Context, application *app.App, state *modState) ([]mod.MOD, error) {
				p := c.printer(cmd)
				var targets []mod.MOD
				if all {
					targets = dependency.PlanDisableAll(state.graph)
				} else {
					for _, name := range args {
						m := mod.MOD{Name: name}
						if m.IsBase() {
							return nil, fmt.Errorf("%w: %s", mod.ErrCannotDisableBaseMOD, m)
						}
						if !state.graph.Contains(m) {
							p.Warn("MOD not installed, skipping: " + m.String())
						}
						targets = append(targets, m)
					}
				}
				return dependency.PlanDisable(state.graph, targets), nil
			}
			isEmpty := func(planned []mod.MOD) bool { return len(planned) == 0 }
			show := func(p *printer, planned []mod.MOD) {
				p.Info(fmt.Sprintf("Planning to disable %d MOD(s):", len(planned)))
				for _, m := range planned {
					p.Say("  - " + m.String())
				}
			}
			execute := func(ctx context.Context, application *app.App, state *modState, p *printer, planned []mod.MOD) error {
				for _, m := range planned {
					if err := state.modList.Disable(m); err != nil {
						return err
					}
					p.Success("Disabled " + m.String())
				}
				p.Success(fmt.Sprintf("Disabled %d MOD(s)", len(planned)))
				return nil
			}
			return runMODMutation(cmd, c, opts, plan, isEmpty, show, execute)
		},
	}
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().BoolVar(&all, "all", false, "Disable all MOD(s) (except base)")
	cmd.Flags().StringVar(&backupExtension, "backup-extension", defaultBackupExtension, "Backup file extension")
	return cmd
}
```

Note: `plan`'s warning print (`p.Warn("MOD not installed, skipping: ...")`) now happens via a `p := c.printer(cmd)` obtained inside the `plan` closure — a second `printer` instance separate from the one `runMODMutation` builds after `plan` returns. `c.printer(cmd)` is cheap and stateless per the existing `cli.printer` implementation (constructs a struct from `cmd`'s streams and the `cli`'s color/quiet settings) — this is not a behavior change, just two calls instead of one.

- [ ] **Step 5: Build and run the enable/disable tests**

Run: `go build ./... && go test ./internal/cli/ -run 'TestMODEnable|TestMODDisable' -v`
Expected: PASS. If `mod_enable_disable_test.go` (the combined test file per the earlier file listing) references `applyMODListChange` directly, it will fail to build — it should not, since it's a black-box test of the commands, but check and report if it does.

- [ ] **Step 6: Run the full check suite**

Run: `mise run default`
Expected: PASS — this is the message-preservation check. If e2e fails on an enable/disable case, compare the printed output against the pre-change behavior (`git show HEAD:internal/cli/mod_enable.go` etc.) and fix the code, not the e2e fixture.

- [ ] **Step 7: Commit**

```bash
git add internal/cli/mod_mutation.go internal/cli/mod_enable.go internal/cli/mod_disable.go
git commit -m ":recycle: Introduce runMODMutation skeleton, migrate enable and disable"
```

- [ ] **Step 8: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Report both in your final output.

---

### Task 4: Migrate `install` onto `runMODMutation` and `EnsureEnabled`

**Files:**
- Modify: `internal/cli/mod_install.go`

**Interfaces:**
- Consumes: `runMODMutation[P any]`, `mutationOpts` from Task 3; `MODList.EnsureEnabled` from Task 2.
- `install`'s `P` type: `installPlan struct { installs, enables []installTarget }`.

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: match, and `git log --oneline -1` shows Task 3's commit at the tip.

- [ ] **Step 1: Confirm the baseline**

Run: `mise run e2e`
Expected: PASS.

- [ ] **Step 2: Rewrite `mod_install.go`'s `newMODInstallCommand`, add `installPlan`, rewrite `executeInstall`**

Keep `installTarget`, `splitInstallTargets`, and `planInstall` unchanged (they stay as free functions — `planInstall` already has the right shape modulo the closure argument list). Add a new type and replace the whole command function.

`modDir` is resolved and validated **before** calling `runMODMutation`, same as the original code did before calling `planInstall` — `plan`/`execute` close over it rather than re-resolving it:

```go
// installPlan is planInstall's result, pre-split into what gets
// downloaded-and-enabled versus merely re-enabled.
type installPlan struct {
	installs, enables []installTarget
}

func newMODInstallCommand(c *cli) *cobra.Command {
	var jobs int
	var yes, ignoreRecommended bool
	var backupExtension string

	cmd := &cobra.Command{
		Use:   "install <mod-spec>...",
		Short: "Install MOD(s) from Factorio MOD Portal (downloads to MOD directory and enables)",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}
			if err := application.RequireGameStopped(); err != nil {
				return err
			}
			modDir, err := application.Runtime.MODDir()
			if err != nil {
				return err
			}
			if info, err := os.Stat(modDir); err != nil || !info.IsDir() {
				return fmt.Errorf("MOD directory does not exist: %s", modDir)
			}

			specs := make([]resolver.Spec, len(args))
			for i, arg := range args {
				spec, err := parseMODSpec(arg)
				if err != nil {
					return err
				}
				specs[i] = spec
			}

			opts := mutationOpts{
				yes:             yes,
				quiet:           c.quiet,
				backupExtension: backupExtension,
				confirmPrompt:   "Do you want to proceed?",
				emptyMessage:    "All specified MOD(s) are already installed and enabled",
			}
			plan := func(ctx context.Context, application *app.App, state *modState) (installPlan, error) {
				targets, err := planInstall(ctx, application, state.graph, specs, jobs, !ignoreRecommended)
				if err != nil {
					return installPlan{}, err
				}
				installs, enables := splitInstallTargets(targets)
				return installPlan{installs: installs, enables: enables}, nil
			}
			isEmpty := func(p installPlan) bool { return len(p.installs) == 0 && len(p.enables) == 0 }
			show := func(p *printer, plan installPlan) {
				if len(plan.installs) > 0 {
					p.Info(fmt.Sprintf("Planning to install %d MOD(s):", len(plan.installs)))
					for _, target := range plan.installs {
						p.Say(fmt.Sprintf("  - %s@%s", target.MOD, target.Release.Version))
					}
				}
				if len(plan.enables) > 0 {
					p.Info(fmt.Sprintf("Planning to enable %d disabled dependency MOD(s):", len(plan.enables)))
					for _, target := range plan.enables {
						p.Say("  - " + target.MOD.String())
					}
				}
			}
			execute := func(ctx context.Context, application *app.App, state *modState, p *printer, plan installPlan) error {
				if err := executeInstall(ctx, application, state.modList, modDir, plan.installs, plan.enables, jobs, p); err != nil {
					return err
				}
				if len(plan.installs) > 0 {
					p.Success(fmt.Sprintf("Installed %d MOD(s)", len(plan.installs)))
				}
				if len(plan.enables) > 0 {
					p.Success(fmt.Sprintf("Enabled %d disabled dependency MOD(s)", len(plan.enables)))
				}
				return nil
			}
			return runMODMutation(cmd, c, opts, plan, isEmpty, show, execute)
		},
	}
	cmd.Flags().IntVarP(&jobs, "jobs", "j", 4, "Number of parallel downloads")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().BoolVar(&ignoreRecommended, "ignore-recommended", false, "Do not resolve or enable recommended dependencies")
	cmd.Flags().StringVar(&backupExtension, "backup-extension", defaultBackupExtension, "Backup file extension")
	return cmd
}
```

`RunE` calls `c.App()` and `application.RequireGameStopped()` once itself, to check the game-stopped precondition before resolving `modDir` and parsing specs — preserving the original code's exact ordering. `runMODMutation` calls both again internally; `c.App()` is memoized (`sync.OnceValues`) and `RequireGameStopped` is a side-effect-free state check, so the duplicate calls are harmless, same as the analogous case in Task 6 (`update`).

Replace `executeInstall` (drop the `c *cli, cmd *cobra.Command` parameters — the printer is now passed in directly):

```go
func executeInstall(ctx context.Context, application *app.App, modList *mod.MODList, modDir string, installs, enables []installTarget, jobs int, p *printer) error {
	if len(installs) > 0 {
		downloads := make([]downloadTarget, 0, len(installs))
		for _, target := range installs {
			if err := validateFilename(target.Release.FileName); err != nil {
				return err
			}
			downloads = append(downloads, downloadTarget{
				MOD:        target.MOD,
				Release:    target.Release,
				OutputPath: filepath.Join(modDir, target.Release.FileName),
			})
		}
		if err := downloadTargets(ctx, application, downloads, jobs); err != nil {
			return err
		}
	}

	for _, target := range installs {
		wasEnabled := false
		if modList.Contains(target.MOD) {
			var err error
			wasEnabled, err = modList.Enabled(target.MOD)
			if err != nil {
				return err
			}
		}
		added, err := modList.EnsureEnabled(target.MOD)
		if err != nil {
			return err
		}
		switch {
		case added:
			p.Success(fmt.Sprintf("Added %s to mod-list.json", target.MOD))
		case !wasEnabled:
			p.Success(fmt.Sprintf("Enabled %s in mod-list.json", target.MOD))
		}
	}
	for _, target := range enables {
		if err := modList.Enable(target.MOD); err != nil {
			// An enable target discovered via the graph should always be in
			// the list; a missing entry means local state changed under us.
			if errors.Is(err, mod.ErrMODNotInList) {
				return fmt.Errorf("cannot enable dependency %s: %w", target.MOD, err)
			}
			return err
		}
		p.Success(fmt.Sprintf("Enabled dependency %s in mod-list.json", target.MOD))
	}
	return nil
}
```

This preserves the exact three-way message behavior of the original (`Added` / `Enabled` / silent) by checking `wasEnabled` before calling `EnsureEnabled`, while still routing the actual mutation through the new helper.

Update imports: `context` and `app` were already imported; no new imports needed beyond what's already in the file (`os`, `fmt`, `filepath`, `errors`, `api`, `dependency`, `mod`, `resolver`, `cobra` all stay).

- [ ] **Step 3: Build and run install's tests**

Run: `go build ./... && go test ./internal/cli/ -run TestMODInstall -v`
Expected: PASS.

- [ ] **Step 4: Run the full check suite**

Run: `mise run default`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/cli/mod_install.go
git commit -m ":recycle: Migrate install onto runMODMutation and EnsureEnabled"
```

- [ ] **Step 6: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Report both in your final output.

---

### Task 5: Migrate `uninstall` onto `runMODMutation` and `InstalledMOD.Remove`

**Files:**
- Modify: `internal/cli/mod_uninstall.go`

**Interfaces:**
- Consumes: `runMODMutation`, `mutationOpts` from Task 3; `InstalledMOD.Remove` from Task 1.
- `uninstall`'s `P` type: `uninstallPlan struct { targets []uninstallTarget; expansionsToDisable []mod.MOD }`.
- The two distinct empty messages (`--all` vs not) are resolved with a plain `string` computed before calling `runMODMutation` — no change to `mutationOpts.emptyMessage`'s type.

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: match, tip at Task 4's commit.

- [ ] **Step 1: Confirm the baseline**

Run: `mise run e2e`
Expected: PASS.

- [ ] **Step 2: Rewrite `mod_uninstall.go`'s `newMODUninstallCommand` and `executeUninstall`**

Keep `uninstallTarget`, its `String()` method, `parseUninstallSpecs`, `planUninstallAll`, `validateUninstallTargets`, `versionInstalled`, `checkDependents`, `enabledExpansions`, and `countInstalledVersions` unchanged. Add `uninstallPlan`, rewrite the command function and `executeUninstall`:

```go
// uninstallPlan is the uninstall command's plan: MODs (or specific
// versions) to remove, plus any expansion MODs --all also disables.
type uninstallPlan struct {
	targets             []uninstallTarget
	expansionsToDisable []mod.MOD
}

func newMODUninstallCommand(c *cli) *cobra.Command {
	var all, yes bool
	var backupExtension string

	cmd := &cobra.Command{
		Use:   "uninstall [mod-spec]...",
		Short: "Uninstall MOD(s) from MOD directory",
		Args:  cobra.ArbitraryArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if all && len(args) > 0 {
				return fmt.Errorf("Cannot specify MOD names with --all option")
			}
			if !all && len(args) == 0 {
				return fmt.Errorf("Must specify MOD names or use --all option")
			}

			emptyMessage := "No MOD(s) to uninstall"
			if all {
				emptyMessage = "No MOD(s) to uninstall or disable"
			}
			opts := mutationOpts{
				yes:             yes,
				quiet:           c.quiet,
				backupExtension: backupExtension,
				confirmPrompt:   "Do you want to uninstall these MOD(s)?",
				emptyMessage:    emptyMessage,
			}
			plan := func(ctx context.Context, application *app.App, state *modState) (uninstallPlan, error) {
				p := c.printer(cmd)
				var requested []uninstallTarget
				var err error
				if all {
					requested = planUninstallAll(state.graph)
				} else {
					requested, err = parseUninstallSpecs(args)
					if err != nil {
						return uninstallPlan{}, err
					}
				}

				targets, err := validateUninstallTargets(p, requested, state, all)
				if err != nil {
					return uninstallPlan{}, err
				}

				var expansionsToDisable []mod.MOD
				if all {
					expansionsToDisable = enabledExpansions(state)
				}
				return uninstallPlan{targets: targets, expansionsToDisable: expansionsToDisable}, nil
			}
			isEmpty := func(plan uninstallPlan) bool {
				return len(plan.targets) == 0 && len(plan.expansionsToDisable) == 0
			}
			show := func(p *printer, plan uninstallPlan) {
				p.Info(fmt.Sprintf("Planning to uninstall %d MOD(s):", len(plan.targets)))
				for _, target := range plan.targets {
					p.Say("  - " + target.String())
				}
				if all && len(plan.expansionsToDisable) > 0 {
					p.Info("Expansion MOD(s) to be disabled:")
					for _, m := range plan.expansionsToDisable {
						p.Say("  - " + m.String())
					}
				}
			}
			execute := func(ctx context.Context, application *app.App, state *modState, p *printer, plan uninstallPlan) error {
				if err := executeUninstall(p, plan.targets, state); err != nil {
					return err
				}
				for _, m := range plan.expansionsToDisable {
					if err := state.modList.Disable(m); err != nil {
						return err
					}
					p.Success("Disabled expansion MOD: " + m.String())
				}
				p.Success(fmt.Sprintf("Uninstalled %d MOD(s)", len(plan.targets)))
				return nil
			}
			return runMODMutation(cmd, c, opts, plan, isEmpty, show, execute)
		},
	}
	cmd.Flags().BoolVar(&all, "all", false, "Uninstall all MOD(s) (base remains enabled, expansions disabled, others removed)")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().StringVar(&backupExtension, "backup-extension", defaultBackupExtension, "Backup file extension")
	return cmd
}
```

Replace `executeUninstall`'s deletion loop to use `InstalledMOD.Remove()`:

```go
func executeUninstall(p *printer, targets []uninstallTarget, state *modState) error {
	for _, target := range targets {
		var toRemove []mod.InstalledMOD
		for _, im := range state.installedMODs {
			if im.MOD != target.MOD {
				continue
			}
			if target.Version == nil || im.Version == *target.Version {
				toRemove = append(toRemove, im)
			}
		}

		for _, im := range toRemove {
			if err := im.Remove(); err != nil {
				return err
			}
		}

		removeFromList := target.Version == nil ||
			len(toRemove) == countInstalledVersions(state.installedMODs, target.MOD)
		if removeFromList && state.modList.Contains(target.MOD) {
			if err := state.modList.Remove(target.MOD); err != nil {
				return err
			}
			p.Success(fmt.Sprintf("Removed %s from mod-list.json", target.MOD))
		}
	}
	return nil
}
```

Drop the now-unused `"os"` import from `mod_uninstall.go` (it was only used by the `os.RemoveAll`/`os.Remove` calls this task removes) — check with `goimports`/`go build` that no other use of `os` remains in the file first.

- [ ] **Step 3: Build and run uninstall's tests**

Run: `go build ./... && go test ./internal/cli/ -run TestMODUninstall -v`
Expected: PASS.

- [ ] **Step 4: Run the full check suite**

Run: `mise run default`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/cli/mod_uninstall.go
git commit -m ":recycle: Migrate uninstall onto runMODMutation and InstalledMOD.Remove"
```

- [ ] **Step 6: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Report both in your final output.

---

### Task 6: Migrate `update` onto `runMODMutation` and `MODList.Replace`

**Files:**
- Modify: `internal/cli/mod_update.go`

**Interfaces:**
- Consumes: `runMODMutation`, `mutationOpts` from Task 3; `MODList.Replace` from Task 2.
- Update keeps its two-stage empty check: the first (`updateTargetMODs` is empty → "No MOD(s) to update") happens in `RunE`, **before** calling `runMODMutation` at all — it needs no network call and no plan. Only the second stage (`findUpdateTargets` returns empty after querying the Portal → "All MOD(s) are up to date") goes through `runMODMutation`'s `plan`/`isEmpty`/`emptyMessage`.

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: match, tip at Task 5's commit.

- [ ] **Step 1: Confirm the baseline**

Run: `mise run e2e`
Expected: PASS.

- [ ] **Step 2: Rewrite `mod_update.go`'s `newMODUpdateCommand` and `executeUpdates`**

Keep `updateTarget`, `updateTargetMODs`, `findUpdateTargets`, and `newestInstalledVersion` unchanged. Rewrite the command function and `executeUpdates`:

```go
func newMODUpdateCommand(c *cli) *cobra.Command {
	var jobs int
	var yes bool
	var backupExtension string

	cmd := &cobra.Command{
		Use:   "update [mod-name]...",
		Short: "Update MOD(s) to their latest versions",
		Args:  cobra.ArbitraryArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}
			if err := application.RequireGameStopped(); err != nil {
				return err
			}
			state, err := loadMODState(application)
			if err != nil {
				return err
			}

			targetMODs, err := updateTargetMODs(args, state.installedMODs)
			if err != nil {
				return err
			}
			p := c.printer(cmd)
			if len(targetMODs) == 0 {
				p.Info("No MOD(s) to update")
				return nil
			}

			opts := mutationOpts{
				yes:             yes,
				quiet:           c.quiet,
				backupExtension: backupExtension,
				confirmPrompt:   "Do you want to update these MOD(s)?",
				emptyMessage:    "All MOD(s) are up to date",
			}
			plan := func(ctx context.Context, application *app.App, state *modState) ([]updateTarget, error) {
				return findUpdateTargets(ctx, application, targetMODs, state.installedMODs, jobs)
			}
			isEmpty := func(targets []updateTarget) bool { return len(targets) == 0 }
			show := func(p *printer, targets []updateTarget) {
				p.Info(fmt.Sprintf("Planning to update %d MOD(s):", len(targets)))
				for _, target := range targets {
					p.Say(fmt.Sprintf("  - %s: %s -> %s", target.MOD, target.CurrentVersion, target.Release.Version))
				}
			}
			execute := func(ctx context.Context, application *app.App, state *modState, p *printer, targets []updateTarget) error {
				if err := executeUpdates(ctx, application, state.modList, targets, jobs, p); err != nil {
					return err
				}
				p.Success(fmt.Sprintf("Updated %d MOD(s)", len(targets)))
				return nil
			}
			return runMODMutation(cmd, c, opts, plan, isEmpty, show, execute)
		},
	}
	cmd.Flags().IntVarP(&jobs, "jobs", "j", 4, "Number of parallel downloads")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().StringVar(&backupExtension, "backup-extension", defaultBackupExtension, "Backup file extension")
	return cmd
}
```

Note: `RunE` calls `c.App()`, `application.RequireGameStopped()`, and `loadMODState` once itself (to compute `targetMODs` for the early-exit check, with the exact same precondition order as the original code), and `runMODMutation` calls all three again internally when it's reached. This is the one place this PR accepts small duplicated calls for the sake of preserving the exact two-message behavior without widening `runMODMutation`'s contract — all three are idempotent/side-effect-free reads (`c.App()` is memoized via `sync.OnceValues`, per `internal/app/app.go`; `RequireGameStopped` is a pure state check; `loadMODState` re-reads `mod-list.json` and rescans the MOD directory, which is cheap and always freshly correct).

Replace `executeUpdates`:

```go
func executeUpdates(ctx context.Context, application *app.App, modList *mod.MODList, targets []updateTarget, jobs int, p *printer) error {
	modDir, err := application.Runtime.MODDir()
	if err != nil {
		return err
	}

	downloads := make([]downloadTarget, 0, len(targets))
	for _, target := range targets {
		if err := validateFilename(target.Release.FileName); err != nil {
			return err
		}
		downloads = append(downloads, downloadTarget{
			MOD:        target.MOD,
			Release:    target.Release,
			OutputPath: filepath.Join(modDir, target.Release.FileName),
		})
	}
	if err := downloadTargets(ctx, application, downloads, jobs); err != nil {
		return err
	}

	for _, target := range targets {
		enabled := true
		wasPresent := modList.Contains(target.MOD)
		if wasPresent {
			enabled, err = modList.Enabled(target.MOD)
			if err != nil {
				return err
			}
		}
		// Replace clears any pinned version in mod-list.json so the newly
		// downloaded release takes effect.
		if err := modList.Replace(target.MOD, mod.MODState{Enabled: enabled}); err != nil {
			return err
		}
		if wasPresent {
			p.Success(fmt.Sprintf("Updated %s to %s", target.MOD, target.Release.Version))
		} else {
			p.Success(fmt.Sprintf("Added %s to mod-list.json", target.MOD))
		}
	}
	return nil
}
```

This funnels both of the original's branches (Remove+Add-if-present, Add-if-absent) through the single `Replace` call, since `Replace` already no-ops its internal `Remove` when absent — `enabled` is computed as `true` for the absent case and the MOD's current state for the present case, exactly matching the original's `mod.MODState{Enabled: enabled}` / `mod.MODState{Enabled: true}` split.

- [ ] **Step 3: Build and run update's tests**

Run: `go build ./... && go test ./internal/cli/ -run TestMODUpdate -v`
Expected: PASS.

- [ ] **Step 4: Run the full check suite**

Run: `mise run default`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/cli/mod_update.go
git commit -m ":recycle: Migrate update onto runMODMutation and MODList.Replace"
```

- [ ] **Step 6: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Report both in your final output.

---

### Task 7: Apply `InstalledMOD.Remove` and `MODList.Replace` inside `sync` (no skeleton adoption)

**Files:**
- Modify: `internal/cli/mod_sync.go`

**Interfaces:**
- Consumes: `InstalledMOD.Remove` from Task 1, `MODList.Replace` from Task 2. Does **not** consume `runMODMutation` — sync's `RunE` structure stays as-is (see plan header for why).

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: match, tip at Task 6's commit.

- [ ] **Step 1: Confirm the baseline**

Run: `mise run e2e`
Expected: PASS.

- [ ] **Step 2: Simplify `executeSyncDeletions`**

`"os"` stays imported in this file regardless — it's still used by `startupSettingsChanged`/`updateStartupSettings` for `mod-settings.dat`. Replace:

```go
func executeSyncDeletions(modsToDelete []mod.InstalledMOD) error {
	for _, installed := range modsToDelete {
		if err := installed.Remove(); err != nil {
			return err
		}
	}
	return nil
}
```

- [ ] **Step 3: Simplify `applySyncChange`'s `syncUpdate` case**

In `applySyncChange`, replace only the `case syncUpdate:` branch:

```go
	case syncUpdate:
		return modList.Replace(m, mod.MODState{Enabled: change.fromEnabled, Version: change.toVersion})
```

Leave `syncEnable` and `syncAdd` untouched — `syncEnable`'s expansion carve-out (`if m.IsExpansion() { return modList.Enable(m) }`) must stay exactly as-is, since `Replace` cannot be used on expansion MODs (Task 2's constraint). The non-expansion path in `syncEnable` currently does `Remove` (only if `Contains`) then unconditional `Add` — this is **not** simplified to `Replace` in this task, because `Replace`'s `Remove` call unconditionally rejects base/expansion MODs even when the MOD in question is absent from the graph in a way `Contains` would catch first; changing this branch risks a subtle behavior shift in a case this survey did not fully enumerate (a non-expansion, non-base MOD is always safe, but leave the existing conditional-Remove structure alone to keep this task's diff minimal and obviously safe). If a future contributor wants to simplify `syncEnable` too, that's a follow-up, not part of PR4.

- [ ] **Step 4: Build and run sync's tests**

Run: `go build ./... && go test ./internal/cli/ -run TestMODSync -v`
Expected: PASS.

- [ ] **Step 5: Run the full check suite**

Run: `mise run default`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/cli/mod_sync.go
git commit -m ":recycle: Use InstalledMOD.Remove and MODList.Replace in sync"
```

- [ ] **Step 7: Confirm the commit landed on the correct branch**

Run: `git log --oneline -1 && git branch --show-current`
Report both in your final output.

---

### Task 8: Full verification and pull request

- [ ] **Step 0: Confirm working directory and branch**

Run: `pwd && git branch --show-current`
Expected: match, tip at Task 7's commit.

- [ ] **Step 1: Confirm no stray references to deleted/replaced helpers**

Run: `grep -rn "applyMODListChange" internal/`
Expected: no matches (function deleted in Task 3).

- [ ] **Step 2: Confirm all six mutation commands still have distinct, correct empty-plan messages**

Run: `grep -rn "emptyMessage:\|p.Info(\"No MOD\|p.Info(\"All " internal/cli/mod_install.go internal/cli/mod_uninstall.go internal/cli/mod_enable.go internal/cli/mod_disable.go internal/cli/mod_update.go`
Expected: five distinct messages matching the table in this plan's design discussion (install: "already installed and enabled"; uninstall: "No MOD(s) to uninstall" / "No MOD(s) to uninstall or disable"; enable: "already enabled"; disable: "already disabled"; update: "No MOD(s) to update" / "All MOD(s) are up to date").

- [ ] **Step 3: Run the full check suite**

Run: `mise run default`
Expected: PASS (test + e2e + vet + lint + fmt-check). If `mise run lint` reports issues in paths under a different worktree name, run `golangci-lint cache clean` once and retry (known stale-cache artifact from prior worktrees in this session, unrelated to this branch's code).

- [ ] **Step 4: Push and open the PR**

Push the branch and create the PR with the `create-pr` skill. Title: `:recycle: Unify mod-list mutation helpers and command skeleton`. Body: summary (three new `internal/mod` helpers — `InstalledMOD.Remove`, `MODList.EnsureEnabled`, `MODList.Replace` — plus a generic `runMODMutation` skeleton adopted by install/uninstall/enable/disable/update; `mod sync` explicitly kept on its own RunE structure per the design's escape hatch, but still uses the two new `mod` helpers internally), explicitly note this PR does not intend any user-visible message changes, `Closes #183`, `Related to #184`. No AI attribution.

- [ ] **Step 5: Verify CI is green and report the PR URL**
