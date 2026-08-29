package cli

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/resolver"
)

// installTarget is one planned action: download-and-enable a new MOD, or
// re-enable an installed-but-disabled dependency.
type installTarget struct {
	MOD       mod.MOD
	Operation dependency.Operation // OpInstall or OpEnable
	Release   api.Release          // meaningful only for OpInstall
}

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
			if info, err := os.Stat(modDir); err != nil {
				return fmt.Errorf("MOD directory does not exist: %s: %w", modDir, err)
			} else if !info.IsDir() {
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
				installedBase := installedBaseVersion(state.installedMODs)
				targets, err := planInstall(ctx, application, state.graph, specs, jobs, !ignoreRecommended, installedBase)
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

func splitInstallTargets(targets []installTarget) (installs, enables []installTarget) {
	for _, target := range targets {
		if target.Operation == dependency.OpInstall {
			installs = append(installs, target)
		} else {
			enables = append(enables, target)
		}
	}
	return installs, enables
}

// planInstall fetches the requested MODs from the Portal, extends the graph
// with them and their required dependencies (recursively), marks disabled
// installed dependencies for enabling, validates the result, and extracts
// the actions to perform.
func planInstall(ctx context.Context, application *app.App, graph *dependency.Graph, specs []resolver.Spec, jobs int, includeRecommended bool, installedBase *mod.MODVersion) ([]installTarget, error) {
	portalAPI, err := application.PortalAPI()
	if err != nil {
		return nil, err
	}
	res := &resolver.Resolver{Portal: portalAPI, Logger: application.Logger, InstalledBase: installedBase}
	releases, err := res.Resolve(ctx, graph, specs, resolver.Options{Jobs: jobs, FollowRecommended: includeRecommended})
	if err != nil {
		return nil, err
	}

	dependency.MarkDisabledDependenciesForEnable(graph, includeRecommended)
	if err := dependency.ValidateInstallGraph(graph); err != nil {
		return nil, err
	}

	var targets []installTarget
	for _, node := range graph.Nodes() {
		switch node.Operation {
		case dependency.OpInstall:
			release, ok := releases[node.MOD]
			if !ok {
				application.Logger.Warn("No release info for MOD, skipping", "mod", node.MOD.Name)
				continue
			}
			targets = append(targets, installTarget{MOD: node.MOD, Operation: dependency.OpInstall, Release: release})
		case dependency.OpEnable:
			targets = append(targets, installTarget{MOD: node.MOD, Operation: dependency.OpEnable})
		}
	}
	return targets, nil
}

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
