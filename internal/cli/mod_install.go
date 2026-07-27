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

			state, err := loadMODState(application)
			if err != nil {
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

			targets, err := planInstall(cmd.Context(), application, state.graph, specs, jobs, !ignoreRecommended)
			if err != nil {
				return err
			}

			p := c.printer(cmd)
			if len(targets) == 0 {
				p.Info("All specified MOD(s) are already installed and enabled")
				return nil
			}

			installs, enables := splitInstallTargets(targets)
			if len(installs) > 0 {
				p.Info(fmt.Sprintf("Planning to install %d MOD(s):", len(installs)))
				for _, target := range installs {
					p.Say(fmt.Sprintf("  - %s@%s", target.MOD, target.Release.Version))
				}
			}
			if len(enables) > 0 {
				p.Info(fmt.Sprintf("Planning to enable %d disabled dependency MOD(s):", len(enables)))
				for _, target := range enables {
					p.Say("  - " + target.MOD.String())
				}
			}

			confirmed, err := confirm(cmd, c.quiet, yes, "Do you want to proceed?")
			if err != nil {
				return err
			}
			if !confirmed {
				return nil
			}

			if err := executeInstall(cmd.Context(), c, cmd, application, state.modList, modDir, installs, enables, jobs); err != nil {
				return err
			}

			modListPath, err := application.Runtime.MODListPath()
			if err != nil {
				return err
			}
			if err := backupIfExists(modListPath, backupExtension); err != nil {
				return err
			}
			if err := state.modList.Save(modListPath); err != nil {
				return err
			}

			if len(installs) > 0 {
				p.Success(fmt.Sprintf("Installed %d MOD(s)", len(installs)))
			}
			if len(enables) > 0 {
				p.Success(fmt.Sprintf("Enabled %d disabled dependency MOD(s)", len(enables)))
			}
			p.Success("Saved mod-list.json")
			return nil
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

func executeInstall(ctx context.Context, c *cli, cmd *cobra.Command, application *app.App, modList *mod.MODList, modDir string, installs, enables []installTarget, jobs int) error {
	p := c.printer(cmd)

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
		if modList.Contains(target.MOD) {
			enabled, err := modList.Enabled(target.MOD)
			if err != nil {
				return err
			}
			if !enabled {
				if err := modList.Enable(target.MOD); err != nil {
					return err
				}
				p.Success(fmt.Sprintf("Enabled %s in mod-list.json", target.MOD))
			}
		} else {
			if err := modList.Add(target.MOD, mod.MODState{Enabled: true}); err != nil {
				return err
			}
			p.Success(fmt.Sprintf("Added %s to mod-list.json", target.MOD))
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
