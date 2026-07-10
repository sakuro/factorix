package cli

import (
	"bytes"
	"encoding/json"
	"path/filepath"
	"strconv"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/mod"
)

func newMODSearchCommand(c *cli) *cobra.Command {
	var hideDeprecated, noHideDeprecated bool
	var page, pageSize int
	var sort, sortOrder, version string
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "search [mod-name]...",
		Short: "Search MOD(s) on Factorio MOD Portal",
		Args:  cobra.ArbitraryArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}

			if version == "" {
				version, err = defaultFactorioVersion(application)
				if err != nil {
					return err
				}
			}

			opts := api.GetMODsOptions{
				Namelist:       args,
				Page:           page,
				PageSize:       strconv.Itoa(pageSize),
				Sort:           sort,
				SortOrder:      sortOrder,
				Version:        version,
				HideDeprecated: hideDeprecatedParam(hideDeprecated, noHideDeprecated),
			}

			portalAPI, err := application.PortalAPI()
			if err != nil {
				return err
			}
			result, err := portalAPI.GetMODs(cmd.Context(), opts)
			if err != nil {
				return err
			}

			p := c.printer(cmd)
			if jsonOutput {
				return outputSearchJSON(p, result.Results)
			}
			return outputSearchTable(p, result.Results)
		},
	}
	cmd.Flags().BoolVar(&hideDeprecated, "hide-deprecated", true, "Hide deprecated MOD(s)")
	// dry-cli generated a --no-hide-deprecated negation for this boolean;
	// cobra has no --no- convention, so the negation is a separate flag.
	cmd.Flags().BoolVar(&noHideDeprecated, "no-hide-deprecated", false, "Include deprecated MOD(s)")
	cmd.MarkFlagsMutuallyExclusive("hide-deprecated", "no-hide-deprecated")
	cmd.Flags().IntVar(&page, "page", 1, "Page number")
	cmd.Flags().IntVar(&pageSize, "page-size", 25, "Results per page (max 500)")
	cmd.Flags().StringVar(&sort, "sort", "", "Sort field (name, created_at, updated_at)")
	cmd.Flags().StringVar(&sortOrder, "sort-order", "", "Sort order (asc, desc)")
	cmd.Flags().StringVar(&version, "version", "", "Filter by Factorio version (default: installed version)")
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output in JSON format")
	return cmd
}

// hideDeprecatedParam maps the --hide-deprecated/--no-hide-deprecated pair
// to the portal query parameter. Ruby only ever sends hide_deprecated=true
// or omits the param (--no-hide-deprecated maps to nil, not false);
// mirrored here so the query the portal sees is identical.
func hideDeprecatedParam(hideDeprecated, noHideDeprecated bool) *bool {
	if noHideDeprecated || !hideDeprecated {
		return nil
	}
	t := true
	return &t
}

// defaultFactorioVersion reads the installed base MOD's major.minor as the
// implicit Factorio version filter, matching Ruby's default_factorio_version.
func defaultFactorioVersion(application *app.App) (string, error) {
	dataDir, err := application.Runtime.DataDir()
	if err != nil {
		return "", err
	}
	base, err := mod.InstalledMODFromDirectory(filepath.Join(dataDir, "base"))
	if err != nil {
		return "", err
	}
	return strconv.Itoa(int(base.Version.Major)) + "." + strconv.Itoa(int(base.Version.Minor)), nil
}

func outputSearchTable(p *printer, mods []api.MODInfo) error {
	if len(mods) == 0 {
		p.Info("No MOD(s) found")
		return nil
	}

	type row struct{ name, title, category, owner, latest string }
	rows := make([]row, len(mods))
	for i, m := range mods {
		latest := ""
		if m.LatestRelease != nil {
			latest = m.LatestRelease.Version.String()
		}
		category, err := api.CategoryFor(m.Category)
		if err != nil {
			return err
		}
		rows[i] = row{m.Name, m.Title, category.Name, m.Owner, latest}
	}

	headers := []string{"NAME", "TITLE", "CATEGORY", "OWNER", "LATEST"}
	widths := make([]int, len(headers))
	for i, h := range headers {
		widths[i] = len(h)
	}
	for _, r := range rows {
		widths[0] = max(widths[0], len(r.name))
		widths[1] = max(widths[1], len(r.title))
		widths[2] = max(widths[2], len(r.category))
		widths[3] = max(widths[3], len(r.owner))
		widths[4] = max(widths[4], len(r.latest))
	}

	p.Printf("%-*s  %-*s  %-*s  %-*s  %-*s\n", widths[0], headers[0], widths[1], headers[1], widths[2], headers[2], widths[3], headers[3], widths[4], headers[4])
	for _, r := range rows {
		p.Printf("%-*s  %-*s  %-*s  %-*s  %-*s\n", widths[0], r.name, widths[1], r.title, widths[2], r.category, widths[3], r.owner, widths[4], r.latest)
	}

	p.Info(strconv.Itoa(len(mods)) + " MOD(s) found")
	return nil
}

func outputSearchJSON(p *printer, mods []api.MODInfo) error {
	type releaseJSON struct {
		Version         string `json:"version"`
		FileName        string `json:"file_name"`
		ReleasedAt      string `json:"released_at"`
		FactorioVersion string `json:"factorio_version"`
		SHA1            string `json:"sha1"`
	}
	type modJSON struct {
		Name           string        `json:"name"`
		Title          string        `json:"title"`
		Owner          string        `json:"owner"`
		Summary        string        `json:"summary"`
		DownloadsCount int           `json:"downloads_count"`
		Category       string        `json:"category"`
		Score          float64       `json:"score"`
		Thumbnail      *string       `json:"thumbnail"`
		LatestRelease  *releaseJSON  `json:"latest_release"`
		Releases       []releaseJSON `json:"releases"`
	}

	toReleaseJSON := func(r api.Release) releaseJSON {
		return releaseJSON{
			Version:         r.Version.String(),
			FileName:        r.FileName,
			ReleasedAt:      r.ReleasedAt.Format("2006-01-02T15:04:05Z07:00"),
			FactorioVersion: r.InfoJSON.FactorioVersion,
			SHA1:            r.SHA1,
		}
	}

	entries := make([]modJSON, len(mods))
	for i, m := range mods {
		var thumbnail *string
		if url := m.ThumbnailURL(); url != "" {
			thumbnail = &url
		}
		var latest *releaseJSON
		if m.LatestRelease != nil {
			r := toReleaseJSON(*m.LatestRelease)
			latest = &r
		}
		releases := make([]releaseJSON, len(m.Releases))
		for j, r := range m.Releases {
			releases[j] = toReleaseJSON(r)
		}
		entries[i] = modJSON{
			Name: m.Name, Title: m.Title, Owner: m.Owner, Summary: m.Summary,
			DownloadsCount: m.DownloadsCount, Category: m.Category, Score: m.Score,
			Thumbnail: thumbnail, LatestRelease: latest, Releases: releases,
		}
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
