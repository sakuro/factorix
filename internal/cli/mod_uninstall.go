package cli

import (
	"fmt"
	"os"
	"strings"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

// uninstallTarget is a MOD to uninstall; a nil Version means every
// installed version.
type uninstallTarget struct {
	MOD     mod.MOD
	Version *mod.MODVersion
}

func (t uninstallTarget) String() string {
	if t.Version != nil {
		return fmt.Sprintf("%s@%s", t.MOD, t.Version)
	}
	return t.MOD.String()
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

			p := c.printer(cmd)
			var requested []uninstallTarget
			if all {
				requested = planUninstallAll(state.graph)
			} else {
				requested, err = parseUninstallSpecs(args)
				if err != nil {
					return err
				}
			}

			targets, err := validateUninstallTargets(p, requested, state, all)
			if err != nil {
				return err
			}

			var expansionsToDisable []mod.MOD
			if all {
				expansionsToDisable = enabledExpansions(state)
			}
			if len(targets) == 0 && len(expansionsToDisable) == 0 {
				if all {
					p.Info("No MOD(s) to uninstall or disable")
				} else {
					p.Info("No MOD(s) to uninstall")
				}
				return nil
			}

			p.Info(fmt.Sprintf("Planning to uninstall %d MOD(s):", len(targets)))
			for _, target := range targets {
				p.Say("  - " + target.String())
			}
			if all && len(expansionsToDisable) > 0 {
				p.Info("Expansion MOD(s) to be disabled:")
				for _, m := range expansionsToDisable {
					p.Say("  - " + m.String())
				}
			}

			confirmed, err := confirm(cmd, c.quiet, yes, "Do you want to uninstall these MOD(s)?")
			if err != nil {
				return err
			}
			if !confirmed {
				return nil
			}

			if err := executeUninstall(p, targets, state); err != nil {
				return err
			}
			if all {
				for _, m := range expansionsToDisable {
					if err := state.modList.Disable(m); err != nil {
						return err
					}
					p.Success("Disabled expansion MOD: " + m.String())
				}
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
			p.Success(fmt.Sprintf("Uninstalled %d MOD(s)", len(targets)))
			p.Success("Saved mod-list.json")
			return nil
		},
	}
	cmd.Flags().BoolVar(&all, "all", false, "Uninstall all MOD(s) (base remains enabled, expansions disabled, others removed)")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().StringVar(&backupExtension, "backup-extension", defaultBackupExtension, "Backup file extension")
	return cmd
}

// parseUninstallSpecs parses "name" or "name@version" specs. Unlike
// download/install specs, "@latest" is not meaningful for uninstalling and
// the version, when present, must be exact.
func parseUninstallSpecs(args []string) ([]uninstallTarget, error) {
	targets := make([]uninstallTarget, len(args))
	for i, arg := range args {
		name, versionStr, hasVersion := strings.Cut(arg, "@")
		target := uninstallTarget{MOD: mod.MOD{Name: name}}
		if hasVersion {
			version, err := mod.ParseMODVersion(versionStr)
			if err != nil {
				return nil, err
			}
			target.Version = &version
		}
		targets[i] = target
	}
	return targets, nil
}

func planUninstallAll(graph *dependency.Graph) []uninstallTarget {
	var targets []uninstallTarget
	for _, node := range graph.Nodes() {
		if node.MOD.IsBase() || node.MOD.IsExpansion() {
			continue
		}
		targets = append(targets, uninstallTarget{MOD: node.MOD})
	}
	return targets
}

// validateUninstallTargets rejects base/expansion MODs, warns about and
// drops targets that are not installed, and (except under --all, where
// everything goes at once) refuses to break enabled dependents.
func validateUninstallTargets(p *printer, requested []uninstallTarget, state *modState, all bool) ([]uninstallTarget, error) {
	var targets []uninstallTarget
	for _, target := range requested {
		if target.MOD.IsBase() {
			return nil, fmt.Errorf("Cannot uninstall base MOD")
		}
		if target.MOD.IsExpansion() {
			return nil, fmt.Errorf("Cannot uninstall expansion MOD: %s", target.MOD)
		}
		if !state.graph.Contains(target.MOD) {
			p.Warn("MOD not installed: " + target.MOD.String())
			continue
		}
		if target.Version != nil && !versionInstalled(state.installedMODs, target.MOD, *target.Version) {
			p.Warn("MOD version not installed: " + target.String())
			continue
		}
		if !all {
			if err := checkDependents(target, state); err != nil {
				return nil, err
			}
		}
		targets = append(targets, target)
	}
	return targets, nil
}

func versionInstalled(installed []mod.InstalledMOD, m mod.MOD, version mod.MODVersion) bool {
	for _, im := range installed {
		if im.MOD == m && im.Version == version {
			return true
		}
	}
	return false
}

// checkDependents refuses the uninstall when an enabled MOD's required
// dependency on the target could no longer be satisfied by the versions
// that would remain installed.
func checkDependents(target uninstallTarget, state *modState) error {
	dependents := state.graph.FindEnabledDependents(target.MOD)
	if len(dependents) == 0 {
		return nil
	}

	var remaining []mod.InstalledMOD
	if target.Version != nil {
		for _, im := range state.installedMODs {
			if im.MOD == target.MOD && im.Version != *target.Version {
				remaining = append(remaining, im)
			}
		}
	}

	var unsatisfied []string
	seen := map[mod.MOD]bool{}
	for _, dependent := range dependents {
		for _, edge := range state.graph.EdgesFrom(dependent) {
			if edge.To != target.MOD || edge.Type != dependency.TypeRequired {
				continue
			}
			satisfiable := false
			for _, im := range remaining {
				if edge.SatisfiedBy(im.Version) {
					satisfiable = true
					break
				}
			}
			if !satisfiable && !seen[dependent] {
				seen[dependent] = true
				unsatisfied = append(unsatisfied, dependent.Name)
			}
		}
	}
	if len(unsatisfied) > 0 {
		return fmt.Errorf("Cannot uninstall %s: the following enabled MOD(s) depend on it: %s",
			target, strings.Join(unsatisfied, ", "))
	}
	return nil
}

func enabledExpansions(state *modState) []mod.MOD {
	var expansions []mod.MOD
	for _, node := range state.graph.Nodes() {
		if !node.MOD.IsExpansion() || !state.modList.Contains(node.MOD) {
			continue
		}
		if enabled, err := state.modList.Enabled(node.MOD); err == nil && enabled {
			expansions = append(expansions, node.MOD)
		}
	}
	return expansions
}

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
			var err error
			if im.Form == mod.FormDirectory {
				err = os.RemoveAll(im.Path)
			} else {
				err = os.Remove(im.Path)
			}
			if err != nil {
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

func countInstalledVersions(installed []mod.InstalledMOD, m mod.MOD) int {
	count := 0
	for _, im := range installed {
		if im.MOD == m {
			count++
		}
	}
	return count
}
