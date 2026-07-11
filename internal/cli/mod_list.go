package cli

import (
	"bytes"
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"strings"
	"sync"

	"github.com/spf13/cobra"
	"golang.org/x/sync/errgroup"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

// listedMOD is one row of the mod list output.
type listedMOD struct {
	Name          string
	Version       mod.MODVersion
	Enabled       bool
	Error         string
	LatestVersion *mod.MODVersion
}

func (m *listedMOD) status() string {
	switch {
	case m.Error != "":
		return "error"
	case m.Enabled:
		return "enabled"
	default:
		return "disabled"
	}
}

func (m *listedMOD) outdated() bool {
	return m.LatestVersion != nil && m.Version.Less(*m.LatestVersion)
}

type listFilters struct {
	enabled  bool
	disabled bool
	errors   bool
	outdated bool
}

func (f listFilters) validate() error {
	var active []string
	for _, flag := range []struct {
		set  bool
		name string
	}{
		{f.enabled, "--enabled"}, {f.disabled, "--disabled"}, {f.errors, "--errors"}, {f.outdated, "--outdated"},
	} {
		if flag.set {
			active = append(active, flag.name)
		}
	}
	if len(active) > 1 {
		return fmt.Errorf("Cannot combine %s options", strings.Join(active, ", "))
	}
	return nil
}

func (f listFilters) name() string {
	switch {
	case f.enabled:
		return "enabled"
	case f.disabled:
		return "disabled"
	case f.errors:
		return "errors"
	case f.outdated:
		return "outdated"
	default:
		return ""
	}
}

func newMODListCommand(c *cli) *cobra.Command {
	var filters listFilters
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List installed MOD(s)",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if err := filters.validate(); err != nil {
				return err
			}
			application, err := c.App()
			if err != nil {
				return err
			}

			state, err := loadMODState(application)
			if err != nil {
				return err
			}
			mods := buildListedMODs(state)
			totalCount := len(mods)

			mods, err = applyListFilters(cmd.Context(), application, mods, filters)
			if err != nil {
				return err
			}
			sortListedMODs(mods)

			p := c.printer(cmd)
			if jsonOutput {
				return outputListJSON(p, mods)
			}
			outputListTable(p, mods, filters, totalCount)
			return nil
		},
	}
	cmd.Flags().BoolVar(&filters.enabled, "enabled", false, "Show only enabled MOD(s)")
	cmd.Flags().BoolVar(&filters.disabled, "disabled", false, "Show only disabled MOD(s)")
	cmd.Flags().BoolVar(&filters.errors, "errors", false, "Show only MOD(s) with dependency errors")
	cmd.Flags().BoolVar(&filters.outdated, "outdated", false, "Show only MOD(s) with available updates")
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output in JSON format")
	return cmd
}

// modState is everything derived from the local installation.
type modState struct {
	modList       *mod.MODList
	installedMODs []mod.InstalledMOD
	graph         *dependency.Graph
	validation    *dependency.ValidationResult
}

func loadMODState(application *app.App) (*modState, error) {
	modListPath, err := application.Runtime.MODListPath()
	if err != nil {
		return nil, err
	}
	modList, err := mod.LoadMODList(modListPath)
	if err != nil {
		return nil, err
	}

	modDir, err := application.Runtime.MODDir()
	if err != nil {
		return nil, err
	}
	dataDir, err := application.Runtime.DataDir()
	if err != nil {
		return nil, err
	}
	installedMODs, err := mod.ScanInstalled(modDir, dataDir, application.Logger, nil)
	if err != nil {
		return nil, err
	}

	graph, err := dependency.BuildGraph(installedMODs, modList)
	if err != nil {
		return nil, err
	}
	validator := &dependency.Validator{Graph: graph, MODList: modList, InstalledMODs: installedMODs}
	return &modState{
		modList:       modList,
		installedMODs: installedMODs,
		graph:         graph,
		validation:    validator.Validate(),
	}, nil
}

func buildListedMODs(state *modState) []*listedMOD {
	// The first validation error per MOD is shown.
	errorByName := map[string]string{}
	for _, validationErr := range state.validation.Errors {
		if validationErr.MOD.Name == "" {
			continue
		}
		if _, ok := errorByName[validationErr.MOD.Name]; !ok {
			errorByName[validationErr.MOD.Name] = validationErr.Message
		}
	}

	var mods []*listedMOD
	for _, node := range state.graph.Nodes() {
		mods = append(mods, &listedMOD{
			Name:    node.MOD.Name,
			Version: node.Version,
			Enabled: node.Enabled,
			Error:   errorByName[node.MOD.Name],
		})
	}
	return mods
}

func applyListFilters(ctx context.Context, application *app.App, mods []*listedMOD, filters listFilters) ([]*listedMOD, error) {
	filter := func(keep func(*listedMOD) bool) []*listedMOD {
		var result []*listedMOD
		for _, m := range mods {
			if keep(m) {
				result = append(result, m)
			}
		}
		return result
	}

	switch {
	case filters.enabled:
		return filter(func(m *listedMOD) bool { return m.Enabled }), nil
	case filters.disabled:
		return filter(func(m *listedMOD) bool { return !m.Enabled }), nil
	case filters.errors:
		return filter(func(m *listedMOD) bool { return m.Error != "" }), nil
	case filters.outdated:
		if err := fetchLatestVersions(ctx, application, mods); err != nil {
			return nil, err
		}
		return filter((*listedMOD).outdated), nil
	default:
		return mods, nil
	}
}

const latestVersionParallelism = 4

// fetchLatestVersions fills LatestVersion from the portal; base and
// expansion MODs are never on the portal and are skipped.
func fetchLatestVersions(ctx context.Context, application *app.App, mods []*listedMOD) error {
	portalAPI, err := application.PortalAPI()
	if err != nil {
		return err
	}

	var mu sync.Mutex
	group, ctx := errgroup.WithContext(ctx)
	group.SetLimit(latestVersionParallelism)
	for _, m := range mods {
		candidate := mod.MOD{Name: m.Name}
		if candidate.IsBase() || candidate.IsExpansion() {
			continue
		}
		group.Go(func() error {
			info, err := portalAPI.GetMOD(ctx, m.Name)
			if err != nil {
				if errors.Is(err, api.ErrMODNotOnPortal) {
					application.Logger.Debug("MOD not found on portal", "mod", m.Name)
					return nil
				}
				return err
			}
			var latest *mod.MODVersion
			for _, release := range info.Releases {
				if latest == nil || latest.Less(release.Version) {
					v := release.Version
					latest = &v
				}
			}
			mu.Lock()
			m.LatestVersion = latest
			mu.Unlock()
			return nil
		})
	}
	return group.Wait()
}

// sortListedMODs orders base first, then expansions, then the rest, each
// group alphabetically.
func sortListedMODs(mods []*listedMOD) {
	rank := func(m *listedMOD) int {
		candidate := mod.MOD{Name: m.Name}
		switch {
		case candidate.IsBase():
			return 0
		case candidate.IsExpansion():
			return 1
		default:
			return 2
		}
	}
	slices.SortStableFunc(mods, func(a, b *listedMOD) int {
		if c := cmp.Compare(rank(a), rank(b)); c != 0 {
			return c
		}
		return cmp.Compare(a.Name, b.Name)
	})
}

func outputListTable(p *printer, mods []*listedMOD, filters listFilters, totalCount int) {
	activeFilter := filters.name()
	if len(mods) == 0 {
		if activeFilter != "" {
			p.Info("No MOD(s) match the specified criteria")
		} else {
			p.Info("No MOD(s) found")
		}
		return
	}

	nameWidth, versionWidth, latestWidth := 4, 7, 6
	for _, m := range mods {
		nameWidth = max(nameWidth, len(m.Name))
		versionWidth = max(versionWidth, len(m.Version.String()))
		if m.LatestVersion != nil {
			latestWidth = max(latestWidth, len(m.LatestVersion.String()))
		}
	}

	if filters.outdated {
		p.Printf("%-*s  %-*s  %-*s  %s\n", nameWidth, "NAME", versionWidth, "VERSION", latestWidth, "LATEST", "STATUS")
		for _, m := range mods {
			latest := ""
			if m.LatestVersion != nil {
				latest = m.LatestVersion.String()
			}
			p.Printf("%-*s  %-*s  %-*s  %s\n", nameWidth, m.Name, versionWidth, m.Version.String(), latestWidth, latest, m.status())
		}
	} else {
		p.Printf("%-*s  %-*s  %s\n", nameWidth, "NAME", versionWidth, "VERSION", "STATUS")
		for _, m := range mods {
			p.Printf("%-*s  %-*s  %s\n", nameWidth, m.Name, versionWidth, m.Version.String(), m.status())
		}
	}

	p.Info(listSummary(len(mods), activeFilter, totalCount))
}

func listSummary(count int, activeFilter string, totalCount int) string {
	switch activeFilter {
	case "enabled":
		return fmt.Sprintf("Summary: %d enabled MOD(s), %d total MOD(s)", count, totalCount)
	case "disabled":
		return fmt.Sprintf("Summary: %d disabled MOD(s), %d total MOD(s)", count, totalCount)
	case "errors":
		return fmt.Sprintf("Summary: %d MOD(s) with errors, %d total MOD(s)", count, totalCount)
	case "outdated":
		return fmt.Sprintf("Summary: %d outdated MOD(s), %d total MOD(s)", count, totalCount)
	default:
		return fmt.Sprintf("Summary: %d MOD(s)", count)
	}
}

func outputListJSON(p *printer, mods []*listedMOD) error {
	type entry struct {
		Name          string  `json:"name"`
		Version       string  `json:"version"`
		Enabled       bool    `json:"enabled"`
		Error         *string `json:"error"`
		LatestVersion string  `json:"latest_version,omitempty"`
	}
	entries := make([]entry, 0, len(mods))
	for _, m := range mods {
		e := entry{Name: m.Name, Version: m.Version.String(), Enabled: m.Enabled}
		if m.Error != "" {
			e.Error = &m.Error
		}
		if m.LatestVersion != nil {
			e.LatestVersion = m.LatestVersion.String()
		}
		entries = append(entries, e)
	}

	var buf bytes.Buffer
	encoder := json.NewEncoder(&buf)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(entries); err != nil {
		return err
	}
	p.Printf("%s", buf.String())
	return nil
}
