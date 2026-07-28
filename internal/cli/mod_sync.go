package cli

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/resolver"
	"github.com/sakuro/factorix/internal/save"
	"github.com/sakuro/factorix/internal/settings"
)

func newMODSyncCommand(c *cli) *cobra.Command {
	var jobs int
	var keepUnlisted, strictVersion, yes, ignoreRecommended bool
	var backupExtension string

	cmd := &cobra.Command{
		Use:   "sync <save-file>",
		Short: "Sync MOD states and startup settings from a save file",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}
			if err := application.RequireGameStopped(); err != nil {
				return err
			}

			p := c.printer(cmd)
			p.Info("Loading save file: " + args[0])
			saveData, err := save.Load(args[0])
			if err != nil {
				return err
			}
			p.Info(fmt.Sprintf("Loaded save file (version: %s, MOD(s): %d)", saveData.Version, len(saveData.MODs)))

			state, err := loadMODState(application)
			if err != nil {
				return err
			}
			modDir, err := application.Runtime.MODDir()
			if err != nil {
				return err
			}

			// Plan phase (no side effects).
			modsToInstall := findMODsToInstall(saveData.MODs, state.installedMODs, strictVersion)
			var installTargets []syncInstallTarget
			var dependencyEntries []save.MODEntry
			if len(modsToInstall) > 0 {
				installTargets, dependencyEntries, err = planSyncInstallation(cmd.Context(), application, state.graph, modsToInstall, modDir, jobs, strictVersion, !ignoreRecommended)
				if err != nil {
					return err
				}
				enrichSyncInstallTargets(installTargets, state.installedMODs)
			}
			// Recommended (and, defensively, required) dependencies resolved
			// above aren't in the save file itself, so downstream planning
			// treats them as if they were: this is what gets them added to
			// mod-list.json and excluded from unlisted-MOD detection.
			effectiveSaveMODs := saveData.MODs
			if len(dependencyEntries) > 0 {
				effectiveSaveMODs = append(append([]save.MODEntry(nil), saveData.MODs...), dependencyEntries...)
			}
			var modsToDelete []mod.InstalledMOD
			if strictVersion {
				modsToDelete = findMODsToDelete(effectiveSaveMODs, state.installedMODs)
			}
			conflictMODs := findConflictMODs(state.modList, effectiveSaveMODs, state.graph)
			changes := planMODListChanges(state.modList, effectiveSaveMODs, state.installedMODs, strictVersion)
			var unlistedMODs []mod.MOD
			if !keepUnlisted {
				unlistedMODs = findUnlistedMODs(state.modList, effectiveSaveMODs, conflictMODs)
			}
			modListChanged := len(installTargets) > 0 || len(conflictMODs) > 0 || len(changes) > 0 || len(unlistedMODs) > 0
			hasChanges := modListChanged || len(modsToDelete) > 0

			settingsPath, err := application.Runtime.MODSettingsPath()
			if err != nil {
				return err
			}
			settingsChanged, err := startupSettingsChanged(saveData.StartupSettings, settingsPath)
			if err != nil {
				return err
			}

			if !hasChanges && !settingsChanged {
				p.Info("Nothing to change")
				return nil
			}

			showSyncPlan(p, installTargets, modsToDelete, conflictMODs, changes, unlistedMODs, settingsChanged)
			confirmed, err := confirm(cmd, c.quiet, yes, "Do you want to apply these changes?")
			if err != nil {
				return err
			}
			if !confirmed {
				return nil
			}

			// Execute phase.
			if len(modsToDelete) > 0 {
				if err := executeSyncDeletions(modsToDelete); err != nil {
					return err
				}
				p.Success(fmt.Sprintf("Deleted %d MOD package(s)", len(modsToDelete)))
			}

			if len(installTargets) > 0 {
				targets := make([]downloadTarget, len(installTargets))
				for i, t := range installTargets {
					targets[i] = t.downloadTarget
				}
				if err := downloadTargets(cmd.Context(), application, targets, jobs); err != nil {
					return err
				}
				p.Success(fmt.Sprintf("Installed %d MOD(s)", len(installTargets)))
			}

			if modListChanged {
				if err := applyMODListSyncChanges(state.modList, conflictMODs, changes, unlistedMODs); err != nil {
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
				p.Success("Updated mod-list.json")
			}

			if settingsChanged {
				if err := updateStartupSettings(saveData.StartupSettings, saveData.Version, settingsPath, backupExtension); err != nil {
					return err
				}
				p.Success("Updated mod-settings.dat")
			}

			p.Success("Sync completed successfully")
			return nil
		},
	}
	cmd.Flags().IntVarP(&jobs, "jobs", "j", 4, "Number of parallel downloads")
	cmd.Flags().BoolVar(&keepUnlisted, "keep-unlisted", false, "Keep MOD(s) not listed in save file enabled")
	cmd.Flags().BoolVar(&strictVersion, "strict-version", false, "Install exact MOD versions from save file")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().BoolVar(&ignoreRecommended, "ignore-recommended", false, "Do not resolve recommended dependencies")
	cmd.Flags().StringVar(&backupExtension, "backup-extension", defaultBackupExtension, "Backup file extension")
	return cmd
}

// syncInstallTarget is a download target plus the currently installed
// version (nil when not installed), kept for plan display.
type syncInstallTarget struct {
	downloadTarget
	fromVersion *mod.MODVersion
}

// syncAction is a planned mod-list.json change. Save files record only
// enabled MODs, so unlike Ruby there is no "disable (disabled in save
// file)" action.
type syncAction uint8

const (
	syncAdd syncAction = iota
	syncEnable
	syncUpdate
)

type syncChange struct {
	mod         mod.MOD
	action      syncAction
	fromEnabled bool
	fromVersion *mod.MODVersion
	toVersion   *mod.MODVersion
}

type syncConflict struct {
	mod           mod.MOD
	conflictsWith mod.MOD
}

// findMODsToInstall returns the save-file MODs that are not installed (in
// any version, or in the exact save version when strict).
func findMODsToInstall(saveMODs []save.MODEntry, installed []mod.InstalledMOD, strict bool) []save.MODEntry {
	var result []save.MODEntry
	for _, entry := range saveMODs {
		m := mod.MOD{Name: entry.Name}
		if m.IsBase() || m.IsExpansion() {
			continue
		}
		found := slices.ContainsFunc(installed, func(i mod.InstalledMOD) bool {
			return i.MOD == m && (!strict || i.Version == entry.Version)
		})
		if !found {
			result = append(result, entry)
		}
	}
	return result
}

// findMODsToDelete returns installed packages newer than the save-file
// version. They must go because Factorio picks the newest zip when several
// versions coexist.
func findMODsToDelete(saveMODs []save.MODEntry, installed []mod.InstalledMOD) []mod.InstalledMOD {
	var result []mod.InstalledMOD
	for _, entry := range saveMODs {
		m := mod.MOD{Name: entry.Name}
		if m.IsBase() || m.IsExpansion() {
			continue
		}
		for _, i := range installed {
			if i.MOD == m && i.Version.Compare(entry.Version) > 0 {
				result = append(result, i)
			}
		}
	}
	return result
}

// planSyncInstallation fetches full portal info for each MOD to install,
// extends the dependency graph with them (for conflict detection), resolves
// their required (and, when includeRecommended is true, recommended)
// dependencies not yet installed anywhere — the same way mod install does
// (#91) — and builds the download targets. A save file always includes
// active required dependencies transitively, so includeRecommended mainly
// matters for a recommended dependency the save's original author had
// disabled; an installed-but-disabled recommended dependency is left
// untouched, since sync has no mechanism to re-enable something the save
// file doesn't list.
func planSyncInstallation(ctx context.Context, application *app.App, graph *dependency.Graph, entries []save.MODEntry, modDir string, jobs int, strict bool, includeRecommended bool) ([]syncInstallTarget, []save.MODEntry, error) {
	portal, err := application.PortalAPI()
	if err != nil {
		return nil, nil, err
	}

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
	for m, release := range releases {
		if !requested[m] {
			dependencyEntries = append(dependencyEntries, save.MODEntry{Name: m.Name, Version: release.Version})
		}
	}

	// Iterate graph.Nodes() rather than the releases map directly: map
	// iteration order is random, and it would otherwise shuffle the
	// "Install:" confirmation list between identical runs (mirrors
	// planInstall's use of graph.Nodes() for the same reason).
	var result []syncInstallTarget
	for _, node := range graph.Nodes() {
		release, ok := releases[node.MOD]
		if !ok {
			continue
		}
		if err := validateFilename(release.FileName); err != nil {
			return nil, nil, err
		}
		result = append(result, syncInstallTarget{downloadTarget: downloadTarget{
			MOD:        node.MOD,
			Release:    release,
			OutputPath: filepath.Join(modDir, release.FileName),
		}})
	}
	return result, dependencyEntries, nil
}

// enrichSyncInstallTargets records the currently installed version of each
// target for display.
func enrichSyncInstallTargets(targets []syncInstallTarget, installed []mod.InstalledMOD) {
	for i := range targets {
		if version, found := newestInstalledVersion(installed, targets[i].MOD); found {
			v := version
			targets[i].fromVersion = &v
		}
	}
}

// findConflictMODs returns currently enabled MODs that an incompatible edge
// connects (in either direction) to a MOD from the save file.
func findConflictMODs(modList *mod.MODList, saveMODs []save.MODEntry, graph *dependency.Graph) []syncConflict {
	var conflicts []syncConflict
	seen := map[mod.MOD]bool{}

	appendConflict := func(conflicting, saveMOD mod.MOD) {
		if !modList.Contains(conflicting) {
			return
		}
		if enabled, err := modList.Enabled(conflicting); err != nil || !enabled {
			return
		}
		if seen[conflicting] {
			return
		}
		seen[conflicting] = true
		conflicts = append(conflicts, syncConflict{mod: conflicting, conflictsWith: saveMOD})
	}

	for _, entry := range saveMODs {
		saveMOD := mod.MOD{Name: entry.Name}
		for _, edge := range graph.EdgesFrom(saveMOD) {
			if edge.Type == dependency.TypeIncompatible {
				appendConflict(edge.To, saveMOD)
			}
		}
		for _, edge := range graph.EdgesTo(saveMOD) {
			if edge.Type == dependency.TypeIncompatible {
				appendConflict(edge.From, saveMOD)
			}
		}
	}
	return conflicts
}

// planMODListChanges computes the mod-list.json changes needed to reflect
// the save file. Save entries are always enabled.
func planMODListChanges(modList *mod.MODList, saveMODs []save.MODEntry, installed []mod.InstalledMOD, strict bool) []syncChange {
	var changes []syncChange
	for _, entry := range saveMODs {
		m := mod.MOD{Name: entry.Name}
		if m.IsBase() {
			continue
		}

		if !modList.Contains(m) {
			var toVersion *mod.MODVersion
			if strict {
				v := entry.Version
				toVersion = &v
			}
			changes = append(changes, syncChange{mod: m, action: syncAdd, toVersion: toVersion})
			continue
		}

		currentEnabled, err := modList.Enabled(m)
		if err != nil {
			continue
		}
		if m.IsExpansion() {
			if !currentEnabled {
				changes = append(changes, syncChange{mod: m, action: syncEnable})
			}
			continue
		}

		// When mod-list.json has no version recorded, fall back to the
		// installed version so already-correct installations are not
		// reported as updates.
		recordedVersion, _ := modList.Version(m)
		currentVersion := recordedVersion
		if currentVersion == nil {
			if v, found := newestInstalledVersion(installed, m); found {
				currentVersion = &v
			}
		}
		saveVersion := entry.Version
		versionChanged := strict && (currentVersion == nil || *currentVersion != saveVersion)

		if !currentEnabled {
			toVersion := recordedVersion
			if strict {
				toVersion = &saveVersion
			}
			changes = append(changes, syncChange{mod: m, action: syncEnable, fromEnabled: currentEnabled, fromVersion: currentVersion, toVersion: toVersion})
		} else if versionChanged {
			changes = append(changes, syncChange{mod: m, action: syncUpdate, fromEnabled: currentEnabled, fromVersion: currentVersion, toVersion: &saveVersion})
		}
	}
	return changes
}

// findUnlistedMODs returns enabled MODs absent from the save file (already
// planned conflict disables excluded).
func findUnlistedMODs(modList *mod.MODList, saveMODs []save.MODEntry, conflicts []syncConflict) []mod.MOD {
	inSave := map[string]bool{}
	for _, entry := range saveMODs {
		inSave[entry.Name] = true
	}
	inConflict := map[mod.MOD]bool{}
	for _, c := range conflicts {
		inConflict[c.mod] = true
	}

	var result []mod.MOD
	for m, state := range modList.All() {
		if !m.IsBase() && state.Enabled && !inSave[m.Name] && !inConflict[m] {
			result = append(result, m)
		}
	}
	return result
}

// startupSettingsChanged reports whether any startup setting from the save
// file differs from the current mod-settings.dat (a missing file counts as
// changed).
func startupSettingsChanged(saveSettings *settings.Section, settingsPath string) (bool, error) {
	if _, err := os.Stat(settingsPath); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return true, nil
		}
		return false, err
	}
	modSettings, err := settings.LoadFile(settingsPath)
	if err != nil {
		return false, err
	}
	startup, err := modSettings.Section("startup")
	if err != nil {
		return false, err
	}
	for key, value := range saveSettings.All() {
		current, ok := startup.Get(key)
		if !ok || !current.Equal(value) {
			return true, nil
		}
	}
	return false, nil
}

func syncVersionTransition(m mod.MOD, from *mod.MODVersion, to mod.MODVersion) string {
	if from != nil && *from != to {
		return fmt.Sprintf("%s (%s → %s)", m, from, to)
	}
	return fmt.Sprintf("%s@%s", m, to)
}

// showSyncPlan prints the combined plan. MODs both deleted and installed
// are downgrades (newer zip removed, save version downloaded) and are shown
// once instead of in three separate sections.
func showSyncPlan(p *printer, installTargets []syncInstallTarget, modsToDelete []mod.InstalledMOD, conflicts []syncConflict, changes []syncChange, unlisted []mod.MOD, settingsChanged bool) {
	p.Info("Planning to sync MOD(s):")

	deleteMODs := map[mod.MOD]bool{}
	for _, m := range modsToDelete {
		deleteMODs[m.MOD] = true
	}
	downgrades := map[mod.MOD]bool{}
	for _, t := range installTargets {
		if deleteMODs[t.MOD] {
			downgrades[t.MOD] = true
		}
	}

	var downgradeTargets, remainingInstalls []syncInstallTarget
	for _, t := range installTargets {
		if downgrades[t.MOD] {
			downgradeTargets = append(downgradeTargets, t)
		} else {
			remainingInstalls = append(remainingInstalls, t)
		}
	}
	if len(downgradeTargets) > 0 {
		p.Say("  Downgrade:")
		for _, t := range downgradeTargets {
			p.Say(fmt.Sprintf("    - %s (%s → %s)", t.MOD, t.fromVersion, t.Release.Version))
		}
	}

	var remainingDeletes []mod.InstalledMOD
	for _, m := range modsToDelete {
		if !downgrades[m.MOD] {
			remainingDeletes = append(remainingDeletes, m)
		}
	}
	if len(remainingDeletes) > 0 {
		p.Say("  Delete (newer than save version):")
		for _, m := range remainingDeletes {
			p.Say(fmt.Sprintf("    - %s@%s (%s)", m.MOD, m.Version, filepath.Base(m.Path)))
		}
	}

	if len(remainingInstalls) > 0 {
		p.Say("  Install:")
		for _, t := range remainingInstalls {
			p.Say("    - " + syncVersionTransition(t.MOD, t.fromVersion, t.Release.Version))
		}
	}

	var enableChanges []syncChange
	for _, ch := range changes {
		if ch.action == syncEnable {
			enableChanges = append(enableChanges, ch)
		}
	}
	if len(enableChanges) > 0 {
		p.Say("  Enable:")
		for _, ch := range enableChanges {
			p.Say("    - " + ch.mod.String())
		}
	}

	if len(conflicts) > 0 || len(unlisted) > 0 {
		p.Say("  Disable:")
		for _, c := range conflicts {
			p.Say(fmt.Sprintf("    - %s (conflicts with %s)", c.mod, c.conflictsWith))
		}
		for _, m := range unlisted {
			p.Say(fmt.Sprintf("    - %s (not listed in save file)", m))
		}
	}

	var updateChanges []syncChange
	for _, ch := range changes {
		if ch.action == syncUpdate && !downgrades[ch.mod] {
			updateChanges = append(updateChanges, ch)
		}
	}
	if len(updateChanges) > 0 {
		p.Say("  Update:")
		for _, ch := range updateChanges {
			p.Say("    - " + syncVersionTransition(ch.mod, ch.fromVersion, *ch.toVersion))
		}
	}

	if settingsChanged {
		p.Say("  Update startup settings")
	}
}

// applyMODListSyncChanges applies conflict disables, planned changes, and
// unlisted disables to the in-memory MOD list.
func applyMODListSyncChanges(modList *mod.MODList, conflicts []syncConflict, changes []syncChange, unlisted []mod.MOD) error {
	for _, c := range conflicts {
		if err := modList.Disable(c.mod); err != nil {
			return err
		}
	}
	for _, ch := range changes {
		if err := applySyncChange(modList, ch); err != nil {
			return err
		}
	}
	for _, m := range unlisted {
		if err := modList.Disable(m); err != nil {
			return err
		}
	}
	return nil
}

func applySyncChange(modList *mod.MODList, change syncChange) error {
	m := change.mod
	switch change.action {
	case syncEnable:
		if modList.Contains(m) {
			if m.IsExpansion() {
				return modList.Enable(m)
			}
			// Re-add so the recorded version can change alongside the state.
			if err := modList.Remove(m); err != nil {
				return err
			}
		}
		return modList.Add(m, mod.MODState{Enabled: true, Version: change.toVersion})
	case syncUpdate:
		return modList.Replace(m, mod.MODState{Enabled: change.fromEnabled, Version: change.toVersion})
	case syncAdd:
		return modList.Add(m, mod.MODState{Enabled: true, Version: change.toVersion})
	default:
		return fmt.Errorf("unexpected change action: %d", change.action)
	}
}

// executeSyncDeletions removes installed MOD packages from disk.
func executeSyncDeletions(modsToDelete []mod.InstalledMOD) error {
	for _, installed := range modsToDelete {
		if err := installed.Remove(); err != nil {
			return err
		}
	}
	return nil
}

// updateStartupSettings merges the save file's startup settings into
// mod-settings.dat, creating the file (with the save's game version) when
// absent.
func updateStartupSettings(saveSettings *settings.Section, gameVersion mod.GameVersion, settingsPath, backupExtension string) error {
	var modSettings *settings.MODSettings
	if _, err := os.Stat(settingsPath); err == nil {
		modSettings, err = settings.LoadFile(settingsPath)
		if err != nil {
			return err
		}
	} else if errors.Is(err, os.ErrNotExist) {
		modSettings = settings.New(gameVersion)
	} else {
		return err
	}

	startup, err := modSettings.Section("startup")
	if err != nil {
		return err
	}
	for key, value := range saveSettings.All() {
		startup.Set(key, value)
	}

	if err := backupIfExists(settingsPath, backupExtension); err != nil {
		return err
	}
	return modSettings.SaveFile(settingsPath)
}
