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

			specs := make([]modSpec, len(args))
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
func planInstall(ctx context.Context, application *app.App, graph *dependency.Graph, specs []modSpec, jobs int, includeRecommended bool) ([]installTarget, error) {
	portalAPI, err := application.PortalAPI()
	if err != nil {
		return nil, err
	}

	// The full endpoint is required: only /full includes each release's
	// dependencies, which drive the recursive resolution below.
	initial, err := fetchMODInfoConcurrently(ctx, jobs, specs, func(ctx context.Context, spec modSpec) (fetchedMODInfo, error) {
		info, err := portalAPI.GetMODFull(ctx, spec.MOD.Name)
		if err != nil {
			return fetchedMODInfo{}, err
		}
		release := findRelease(info, spec)
		if release == nil {
			return fetchedMODInfo{}, fmt.Errorf("Release not found for %s@%s", spec.MOD.Name, specVersionLabel(spec))
		}
		return fetchedMODInfo{MOD: spec.MOD, MODInfo: info, Release: *release}, nil
	})
	if err != nil {
		return nil, err
	}

	releases := map[mod.MOD]api.Release{}
	frontier := make([]mod.MOD, 0, len(initial))
	for _, info := range initial {
		if err := graph.AddUninstalledMOD(info.MOD, info.Release.Version, info.Release.InfoJSON.Dependencies); err != nil {
			return nil, err
		}
		releases[info.MOD] = info.Release
		frontier = append(frontier, info.MOD)
	}

	if err := resolveInstallDependencies(ctx, application, graph, releases, frontier, jobs, includeRecommended); err != nil {
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

// resolveInstallDependencies walks the required (and, when includeRecommended
// is true, recommended) edges of newly-added graph nodes and fetches MODs
// not yet in the graph, extending it recursively. Recommended dependencies
// are on by default, so they're fetched the same as required ones unless
// the caller opts out. A dependency that cannot be fetched or has no
// compatible release is skipped with a warning rather than failing the
// install.
func resolveInstallDependencies(ctx context.Context, application *app.App, graph *dependency.Graph, releases map[mod.MOD]api.Release, frontier []mod.MOD, jobs int, includeRecommended bool) error {
	portalAPI, err := application.PortalAPI()
	if err != nil {
		return err
	}

	processed := map[mod.MOD]bool{}
	for len(frontier) > 0 {
		type missingDep struct {
			mod         mod.MOD
			requirement *dependency.VersionRequirement
			requiredBy  mod.MOD
		}
		var missing []missingDep
		for _, m := range frontier {
			if processed[m] {
				continue
			}
			processed[m] = true
			for _, edge := range graph.EdgesFrom(m) {
				relevant := edge.Type == dependency.TypeRequired || (includeRecommended && edge.Type == dependency.TypeRecommended)
				if !relevant {
					continue
				}
				if graph.Contains(edge.To) {
					continue
				}
				missing = append(missing, missingDep{mod: edge.To, requirement: edge.Requirement, requiredBy: m})
			}
		}
		frontier = nil
		if len(missing) == 0 {
			continue
		}

		specs := make([]modSpec, len(missing))
		for i, dep := range missing {
			specs[i] = modSpec{MOD: dep.mod}
		}
		results, err := fetchMODInfoConcurrently(ctx, jobs, specs, func(ctx context.Context, spec modSpec) (fetchedMODInfo, error) {
			var requirement *dependency.VersionRequirement
			var requiredBy mod.MOD
			for _, dep := range missing {
				if dep.mod == spec.MOD {
					requirement = dep.requirement
					requiredBy = dep.requiredBy
					break
				}
			}
			info, err := portalAPI.GetMODFull(ctx, spec.MOD.Name)
			if err != nil {
				application.Logger.Warn("Skipping dependency", "mod", spec.MOD.Name, "required_by", requiredBy.Name, "reason", err)
				return fetchedMODInfo{}, nil
			}
			release := findCompatibleRelease(info, requirement)
			if release == nil {
				application.Logger.Warn("Skipping dependency", "mod", spec.MOD.Name, "required_by", requiredBy.Name, "reason", "no compatible release found")
				return fetchedMODInfo{}, nil
			}
			return fetchedMODInfo{MOD: spec.MOD, MODInfo: info, Release: *release}, nil
		})
		if err != nil {
			return err
		}

		for _, r := range results {
			if r.MODInfo == nil {
				continue // skipped above
			}
			if err := graph.AddUninstalledMOD(r.MOD, r.Release.Version, r.Release.InfoJSON.Dependencies); err != nil {
				return err
			}
			releases[r.MOD] = r.Release
			frontier = append(frontier, r.MOD)
		}
	}
	return nil
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
