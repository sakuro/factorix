package cli

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/changelog"
	"github.com/sakuro/factorix/internal/mod"
)

func newMODChangelogCommand(c *cli) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "changelog",
		Short: "Manage MOD changelogs",
	}
	cmd.AddCommand(
		newMODChangelogAddCommand(c),
		newMODChangelogCheckCommand(c),
		newMODChangelogExtractCommand(c),
		newMODChangelogReleaseCommand(c),
	)
	return cmd
}

func newMODChangelogAddCommand(c *cli) *cobra.Command {
	var version, category, changelogPath string

	cmd := &cobra.Command{
		Use:   "add <entry>...",
		Short: "Add an entry to MOD changelog",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			target, err := parseChangelogVersion(version)
			if err != nil {
				return err
			}
			log, err := changelog.Load(changelogPath)
			if err != nil {
				return err
			}
			if err := log.AddEntry(target, category, strings.Join(args, " ")); err != nil {
				return err
			}
			if err := log.Save(changelogPath); err != nil {
				return err
			}
			c.printer(cmd).Success(fmt.Sprintf("Added entry to %s [%s]", changelogVersionLabel(target), category))
			return nil
		},
	}
	cmd.Flags().StringVar(&version, "version", changelog.Unreleased, "Version (X.Y.Z or Unreleased)")
	cmd.Flags().StringVar(&category, "category", "", "Category (e.g., Features, Bugfixes)")
	cmd.Flags().StringVar(&changelogPath, "changelog", "changelog.txt", "Path to changelog file")
	_ = cmd.MarkFlagRequired("category")
	return cmd
}

func newMODChangelogCheckCommand(c *cli) *cobra.Command {
	var release bool
	var changelogPath, infoJSONPath string

	cmd := &cobra.Command{
		Use:   "check",
		Short: "Validate MOD changelog structure",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			var validationErrors []string

			log, err := changelog.Load(changelogPath)
			switch {
			case errors.Is(err, changelog.ErrParse):
				validationErrors = append(validationErrors, "Failed to parse changelog: "+err.Error())
			case err != nil:
				return err
			default:
				validationErrors = append(validationErrors, validateUnreleasedPosition(log)...)
				validationErrors = append(validationErrors, validateVersionOrder(log)...)
				if release {
					releaseErrors, err := validateReleaseMode(log, infoJSONPath)
					if err != nil {
						return err
					}
					validationErrors = append(validationErrors, releaseErrors...)
				}
			}

			p := c.printer(cmd)
			if len(validationErrors) == 0 {
				p.Success("Changelog is valid")
				return nil
			}
			p.Error("Changelog validation failed:")
			for _, msg := range validationErrors {
				p.Say("  - " + msg)
			}
			return errors.New("Changelog validation failed")
		},
	}
	cmd.Flags().BoolVar(&release, "release", false, "Disallow Unreleased section")
	cmd.Flags().StringVar(&changelogPath, "changelog", "changelog.txt", "Path to changelog file")
	cmd.Flags().StringVar(&infoJSONPath, "info-json", "info.json", "Path to info.json file")
	return cmd
}

func validateUnreleasedPosition(log *changelog.Changelog) []string {
	for i, section := range log.Sections() {
		if section.Version == nil && i != 0 {
			return []string{"Unreleased section must be the first section"}
		}
	}
	return nil
}

func validateVersionOrder(log *changelog.Changelog) []string {
	var errs []string
	var previous *mod.MODVersion
	for _, section := range log.Sections() {
		if section.Version == nil {
			continue
		}
		if previous != nil && previous.Compare(*section.Version) <= 0 {
			errs = append(errs, fmt.Sprintf("Versions are not in descending order: %s should be greater than %s", previous, section.Version))
		}
		previous = section.Version
	}
	return errs
}

// validateReleaseMode returns validation errors for release mode; a missing
// info.json is a validation error, but an unreadable or malformed one is a
// hard error, as in Ruby.
func validateReleaseMode(log *changelog.Changelog, infoJSONPath string) ([]string, error) {
	var errs []string
	if _, ok := log.FindSection(nil); ok {
		errs = append(errs, "Unreleased section is not allowed in release mode")
	}

	data, err := os.ReadFile(infoJSONPath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return append(errs, "info.json not found: "+infoJSONPath), nil
		}
		return nil, err
	}
	info, err := mod.ParseInfoJSON(data)
	if err != nil {
		return nil, err
	}

	for _, section := range log.Sections() {
		if section.Version == nil {
			continue
		}
		if info.Version != *section.Version {
			errs = append(errs, fmt.Sprintf("info.json version (%s) does not match first changelog version (%s)", info.Version, section.Version))
		}
		break
	}
	return errs, nil
}

func newMODChangelogExtractCommand(c *cli) *cobra.Command {
	var version, changelogPath string
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "extract",
		Short: "Extract a changelog section for a specific version",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			target, err := parseChangelogVersion(version)
			if err != nil {
				return err
			}
			log, err := changelog.Load(changelogPath)
			if err != nil {
				return err
			}
			section, ok := log.FindSection(target)
			if !ok {
				return fmt.Errorf("version not found: %s", changelogVersionLabel(target))
			}

			p := c.printer(cmd)
			if jsonOutput {
				data, err := extractSectionJSON(section)
				if err != nil {
					return err
				}
				p.Println(string(data))
				return nil
			}
			p.Println(changelog.FormatSection(section))
			return nil
		},
	}
	cmd.Flags().StringVar(&version, "version", "", "Version (X.Y.Z or Unreleased)")
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output in JSON format")
	cmd.Flags().StringVar(&changelogPath, "changelog", "changelog.txt", "Path to changelog file")
	_ = cmd.MarkFlagRequired("version")
	return cmd
}

// extractSectionJSON renders a section as pretty JSON with the same key
// and category order as Ruby's JSON.pretty_generate (encoding/json maps
// would sort category names, so the object is assembled by hand).
func extractSectionJSON(section *changelog.Section) ([]byte, error) {
	var compact bytes.Buffer
	compact.WriteString(`{"version":`)
	if err := appendJSON(&compact, section.VersionLabel()); err != nil {
		return nil, err
	}
	compact.WriteString(`,"date":`)
	if section.Date == "" {
		compact.WriteString("null")
	} else if err := appendJSON(&compact, section.Date); err != nil {
		return nil, err
	}
	compact.WriteString(`,"entries":{`)
	for i, category := range section.Categories {
		if i > 0 {
			compact.WriteString(",")
		}
		if err := appendJSON(&compact, category.Name); err != nil {
			return nil, err
		}
		compact.WriteString(":")
		if err := appendJSON(&compact, category.Entries); err != nil {
			return nil, err
		}
	}
	compact.WriteString("}}")

	var pretty bytes.Buffer
	if err := json.Indent(&pretty, compact.Bytes(), "", "  "); err != nil {
		return nil, err
	}
	return pretty.Bytes(), nil
}

func appendJSON(b *bytes.Buffer, v any) error {
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}
	b.Write(data)
	return nil
}

func newMODChangelogReleaseCommand(c *cli) *cobra.Command {
	var version, date, changelogPath, infoJSONPath string

	cmd := &cobra.Command{
		Use:   "release",
		Short: "Convert Unreleased changelog section to a versioned section",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			target, err := resolveReleaseVersion(version, infoJSONPath)
			if err != nil {
				return err
			}
			releaseDate := date
			if releaseDate == "" {
				releaseDate = time.Now().UTC().Format("2006-01-02")
			}

			log, err := changelog.Load(changelogPath)
			if err != nil {
				return err
			}
			if err := log.ReleaseSection(target, releaseDate); err != nil {
				return err
			}
			if err := log.Save(changelogPath); err != nil {
				return err
			}
			c.printer(cmd).Success(fmt.Sprintf("Converted Unreleased to %s (%s)", target, releaseDate))
			return nil
		},
	}
	cmd.Flags().StringVar(&version, "version", "", "Version (X.Y.Z, default: from info.json)")
	cmd.Flags().StringVar(&date, "date", "", "Release date (YYYY-MM-DD, default: today UTC)")
	cmd.Flags().StringVar(&changelogPath, "changelog", "changelog.txt", "Path to changelog file")
	cmd.Flags().StringVar(&infoJSONPath, "info-json", "info.json", "Path to info.json file")
	return cmd
}

func resolveReleaseVersion(version, infoJSONPath string) (mod.MODVersion, error) {
	if version != "" {
		return mod.ParseMODVersion(version)
	}
	data, err := os.ReadFile(infoJSONPath)
	if err != nil {
		return mod.MODVersion{}, err
	}
	info, err := mod.ParseInfoJSON(data)
	if err != nil {
		return mod.MODVersion{}, err
	}
	return info.Version, nil
}

// parseChangelogVersion maps a --version value to a section version:
// nil for Unreleased (case-insensitive), a parsed MODVersion otherwise.
func parseChangelogVersion(s string) (*mod.MODVersion, error) {
	if strings.EqualFold(s, changelog.Unreleased) {
		return nil, nil
	}
	v, err := mod.ParseMODVersion(s)
	if err != nil {
		return nil, err
	}
	return &v, nil
}

func changelogVersionLabel(version *mod.MODVersion) string {
	if version == nil {
		return changelog.Unreleased
	}
	return version.String()
}
