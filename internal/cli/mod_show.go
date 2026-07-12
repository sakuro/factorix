package cli

import (
	"bytes"
	"encoding/json"
	"fmt"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

func newMODShowCommand(c *cli) *cobra.Command {
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "show <mod-name>",
		Short: "Show MOD details from Factorio MOD Portal",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			target := mod.MOD{Name: args[0]}
			if target.IsBase() {
				return fmt.Errorf("Cannot show base MOD")
			}
			if target.IsExpansion() {
				return fmt.Errorf("Cannot show expansion MOD: %s", target.Name)
			}

			application, err := c.App()
			if err != nil {
				return err
			}
			portalAPI, err := application.PortalAPI()
			if err != nil {
				return err
			}
			info, err := portalAPI.GetMODFull(cmd.Context(), target.Name)
			if err != nil {
				return err
			}
			localStatus, err := fetchLocalStatus(application, target)
			if err != nil {
				return err
			}

			p := c.printer(cmd)
			if jsonOutput {
				return outputShowJSON(p, info, localStatus)
			}
			return displayShow(p, info, localStatus)
		},
	}
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output in JSON format")
	return cmd
}

type localMODStatus struct {
	Installed    bool
	Enabled      bool
	LocalVersion *mod.MODVersion
}

func fetchLocalStatus(application *app.App, target mod.MOD) (localMODStatus, error) {
	modListPath, err := application.Runtime.MODListPath()
	if err != nil {
		return localMODStatus{}, err
	}
	modList, err := mod.LoadMODList(modListPath)
	if err != nil {
		return localMODStatus{}, err
	}

	var status localMODStatus
	status.Enabled = modList.Contains(target) && func() bool { e, _ := modList.Enabled(target); return e }()

	modDir, err := application.Runtime.MODDir()
	if err != nil {
		return localMODStatus{}, err
	}
	dataDir, err := application.Runtime.DataDir()
	if err != nil {
		return localMODStatus{}, err
	}
	installed, err := mod.ScanInstalled(modDir, dataDir, application.Logger, nil)
	if err != nil {
		return localMODStatus{}, err
	}
	for _, im := range installed {
		if im.MOD == target {
			status.Installed = true
			v := im.Version
			status.LocalVersion = &v
			break
		}
	}
	return status, nil
}

func latestReleaseOf(info *api.MODInfo) *api.Release {
	if info.LatestRelease != nil {
		return info.LatestRelease
	}
	return latestByVersion(info.Releases)
}

func latestByVersion(releases []api.Release) *api.Release {
	if len(releases) == 0 {
		return nil
	}
	latest := &releases[0]
	for i := 1; i < len(releases); i++ {
		if latest.Version.Less(releases[i].Version) {
			latest = &releases[i]
		}
	}
	return latest
}

func displayShow(p *printer, info *api.MODInfo, status localMODStatus) error {
	title := color.New(color.Bold, color.Underline)
	header := color.New(color.Bold)
	incompatible := color.New(color.FgRed)
	if !colorEnabled() {
		title.DisableColor()
		header.DisableColor()
		incompatible.DisableColor()
	}

	p.Println(title.Sprint(info.Title))
	p.Println()
	if info.Summary != "" {
		p.Println(info.Summary)
	}
	p.Println()

	if err := displayBasicInfo(p, info, status); err != nil {
		return err
	}

	p.Println(header.Sprint("Links"))
	p.Println("  MOD Portal: https://mods.factorio.com/mod/" + info.Name)
	if info.SourceURL != "" {
		p.Println("  Source: " + info.SourceURL)
	}
	if info.Homepage != "" {
		p.Println("  Homepage: " + info.Homepage)
	}
	p.Println()

	latest := latestReleaseOf(info)
	if latest == nil {
		return nil
	}
	required, optional, incompatibleDeps := classifyDependencies(latest.InfoJSON.Dependencies)

	if len(required) > 0 {
		p.Println(header.Sprint("Dependencies"))
		for _, d := range required {
			p.Println("  " + d)
		}
		p.Println()
	}
	if len(optional) > 0 {
		p.Println(header.Sprint("Optional Dependencies"))
		for _, d := range optional {
			p.Println("  " + d)
		}
		p.Println()
	}
	if len(incompatibleDeps) > 0 {
		p.Println(header.Sprint("Incompatibilities"))
		for _, d := range incompatibleDeps {
			p.Println("  " + incompatible.Sprint(d))
		}
		p.Println()
	}
	return nil
}

func displayBasicInfo(p *printer, info *api.MODInfo, status localMODStatus) error {
	latest := latestReleaseOf(info)
	factorioVersion := "N/A"
	if latest != nil && latest.InfoJSON.FactorioVersion != "" {
		factorioVersion = latest.InfoJSON.FactorioVersion
	}

	type row struct{ label, value string }
	rows := []row{{"Status", formatLocalStatus(status)}}
	if latest != nil {
		rows = append(rows, row{"Latest Version", latest.Version.String()})
	} else {
		rows = append(rows, row{"Latest Version", "N/A"})
	}
	if status.Installed && status.LocalVersion != nil {
		note := ""
		if latest != nil && *status.LocalVersion != latest.Version {
			note = " (update available)"
		}
		rows = append(rows, row{"Installed Version", status.LocalVersion.String() + note})
	}
	category, err := api.CategoryFor(info.Category)
	if err != nil {
		return err
	}
	rows = append(rows,
		row{"Author", info.Owner},
		row{"Category", category.Name},
		row{"License", formatLicense(info)},
		row{"Factorio Version", factorioVersion},
		row{"Downloads", fmt.Sprintf("%d", info.DownloadsCount)},
	)

	width := 0
	for _, r := range rows {
		width = max(width, len(r.label))
	}
	for _, r := range rows {
		p.Printf("%-*s  %s\n", width, r.label, r.value)
	}
	p.Println()
	return nil
}

func formatLocalStatus(status localMODStatus) string {
	if !status.Installed {
		return "Not installed"
	}
	if status.Enabled {
		return "Enabled"
	}
	return "Disabled"
}

func formatLicense(info *api.MODInfo) string {
	if info.License == nil {
		return "N/A"
	}
	return info.License.Title
}

// classifyDependencies splits raw dependency strings into required, optional,
// and incompatible dependencies using dependency.Parse, so classification
// agrees with the rest of the codebase (recommended-dependency handling is
// tracked separately in #90). Malformed entries from the Portal API are
// skipped rather than failing the whole display — this command only
// displays dependencies, it never resolves them.
func classifyDependencies(raw []string) (required, optional, incompatible []string) {
	for _, dep := range raw {
		entry, err := dependency.Parse(dep)
		if err != nil {
			continue
		}

		s := entry.MOD.Name
		if entry.Requirement != nil {
			s += " " + entry.Requirement.String()
		}

		switch entry.Type {
		case dependency.TypeRequired:
			required = append(required, s)
		case dependency.TypeOptional, dependency.TypeHiddenOptional:
			optional = append(optional, s)
		case dependency.TypeIncompatible:
			incompatible = append(incompatible, s)
		case dependency.TypeLoadNeutral, dependency.TypeRecommended:
			// No display section yet for these buckets (see #90).
		}
	}
	return required, optional, incompatible
}

func outputShowJSON(p *printer, info *api.MODInfo, status localMODStatus) error {
	latest := latestReleaseOf(info)
	factorioVersion := ""
	var latestVersion *string
	var dependencies []string
	if latest != nil {
		factorioVersion = latest.InfoJSON.FactorioVersion
		v := latest.Version.String()
		latestVersion = &v
		dependencies = latest.InfoJSON.Dependencies
	}
	if dependencies == nil {
		dependencies = []string{}
	}

	var installedVersion *string
	var updateAvailable *bool
	if status.Installed {
		if status.LocalVersion != nil {
			v := status.LocalVersion.String()
			installedVersion = &v
			if latestVersion != nil {
				u := v != *latestVersion
				updateAvailable = &u
			}
		}
	}

	var license *string
	if info.License != nil {
		license = &info.License.Title
	}
	var sourceURL, homepage *string
	if info.SourceURL != "" {
		sourceURL = &info.SourceURL
	}
	if info.Homepage != "" {
		homepage = &info.Homepage
	}
	category, err := api.CategoryFor(info.Category)
	if err != nil {
		return err
	}

	doc := struct {
		Name             string  `json:"name"`
		Title            string  `json:"title"`
		Summary          string  `json:"summary"`
		Author           string  `json:"author"`
		Category         string  `json:"category"`
		License          *string `json:"license"`
		FactorioVersion  string  `json:"factorio_version"`
		DownloadsCount   int     `json:"downloads_count"`
		Status           string  `json:"status"`
		LatestVersion    *string `json:"latest_version"`
		InstalledVersion *string `json:"installed_version"`
		UpdateAvailable  *bool   `json:"update_available"`
		Links            struct {
			ModPortal string  `json:"mod_portal"`
			Source    *string `json:"source"`
			Homepage  *string `json:"homepage"`
		} `json:"links"`
		Dependencies []string `json:"dependencies"`
	}{
		Name: info.Name, Title: info.Title, Summary: info.Summary, Author: info.Owner,
		Category: category.Name, License: license, FactorioVersion: factorioVersion,
		DownloadsCount: info.DownloadsCount, Status: jsonLocalStatus(status),
		LatestVersion: latestVersion, InstalledVersion: installedVersion, UpdateAvailable: updateAvailable,
		Dependencies: dependencies,
	}
	doc.Links.ModPortal = "https://mods.factorio.com/mod/" + info.Name
	doc.Links.Source = sourceURL
	doc.Links.Homepage = homepage

	var buf bytes.Buffer
	encoder := json.NewEncoder(&buf)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(doc); err != nil {
		return err
	}
	p.Printf("%s", buf.String())
	return nil
}

func jsonLocalStatus(status localMODStatus) string {
	if !status.Installed {
		return "not_installed"
	}
	if status.Enabled {
		return "enabled"
	}
	return "disabled"
}
