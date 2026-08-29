package cli

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"

	"github.com/spf13/cobra"
	"golang.org/x/sync/errgroup"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/resolver"
)

// updateTarget is one MOD with a newer release available.
type updateTarget struct {
	MOD            mod.MOD
	CurrentVersion mod.MODVersion
	Release        api.Release
}

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

// updateTargetMODs resolves the MODs to check: the named ones (base and
// expansion MODs rejected), or every installed MOD except base/expansions
// when no names are given.
func updateTargetMODs(args []string, installed []mod.InstalledMOD) ([]mod.MOD, error) {
	if len(args) > 0 {
		targets := make([]mod.MOD, len(args))
		for i, name := range args {
			m := mod.MOD{Name: name}
			if m.IsBase() {
				return nil, fmt.Errorf("Cannot update base MOD")
			}
			if m.IsExpansion() {
				return nil, fmt.Errorf("Cannot update expansion MOD: %s", m)
			}
			targets[i] = m
		}
		return targets, nil
	}

	seen := map[mod.MOD]bool{}
	var targets []mod.MOD
	for _, im := range installed {
		if seen[im.MOD] || im.MOD.IsBase() || im.MOD.IsExpansion() {
			continue
		}
		seen[im.MOD] = true
		targets = append(targets, im.MOD)
	}
	return targets, nil
}

// findUpdateTargets asks the Portal for each MOD's latest release and keeps
// those newer than the newest installed version. MODs not installed or not
// on the Portal are silently skipped, matching Ruby.
func findUpdateTargets(ctx context.Context, application *app.App, targetMODs []mod.MOD, installed []mod.InstalledMOD, jobs int) ([]updateTarget, error) {
	portalAPI, err := application.PortalAPI()
	if err != nil {
		return nil, err
	}
	installedBase := installedBaseVersion(installed)

	// Each goroutine writes only its own index, so no lock is needed.
	results := make([]*updateTarget, len(targetMODs))
	group, ctx := errgroup.WithContext(ctx)
	group.SetLimit(jobs)
	for i, m := range targetMODs {
		current, ok := newestInstalledVersion(installed, m)
		if !ok {
			continue
		}
		group.Go(func() error {
			info, err := portalAPI.GetMODFull(ctx, m.Name)
			if err != nil {
				if errors.Is(err, api.ErrMODNotOnPortal) {
					application.Logger.Debug("MOD not found on portal", "mod", m.Name)
					return nil
				}
				return err
			}
			latest := resolver.SelectLatest(info, installedBase)
			if latest == nil || !current.Less(latest.Version) {
				return nil
			}
			results[i] = &updateTarget{MOD: m, CurrentVersion: current, Release: *latest}
			return nil
		})
	}
	if err := group.Wait(); err != nil {
		return nil, err
	}

	var targets []updateTarget
	for _, r := range results {
		if r != nil {
			targets = append(targets, *r)
		}
	}
	return targets, nil
}

func newestInstalledVersion(installed []mod.InstalledMOD, m mod.MOD) (mod.MODVersion, bool) {
	var newest mod.MODVersion
	found := false
	for _, im := range installed {
		if im.MOD != m {
			continue
		}
		if !found || newest.Less(im.Version) {
			newest = im.Version
			found = true
		}
	}
	return newest, found
}

// installedBaseVersion returns the installed base MOD's version, or nil
// when it cannot be determined (e.g. a missing or corrupted data
// directory) - callers then skip the game-version compatibility check
// rather than reject every release.
func installedBaseVersion(installed []mod.InstalledMOD) *mod.MODVersion {
	version, ok := newestInstalledVersion(installed, mod.MOD{Name: "base"})
	if !ok {
		return nil
	}
	return &version
}

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
