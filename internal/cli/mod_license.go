package cli

import (
	"encoding/json"
	"errors"
	"strings"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/api"
)

func newMODLicenseCommand(c *cli) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "license",
		Short: "Look up standard MOD Portal license identifiers",
	}
	cmd.AddCommand(
		newMODLicenseListCommand(c),
		newMODLicenseShowCommand(c),
	)
	return cmd
}

func newMODLicenseListCommand(c *cli) *cobra.Command {
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List standard MOD Portal license identifiers",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			p := c.printer(cmd)
			licenses := api.StandardLicenses()
			if jsonOutput {
				return outputLicenseListJSON(p, licenses)
			}
			outputLicenseListTable(p, licenses)
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output in JSON format")
	return cmd
}

func outputLicenseListTable(p *printer, licenses []api.License) {
	idWidth, nameWidth := len("ID"), len("NAME")
	for _, license := range licenses {
		idWidth = max(idWidth, len(license.ID))
		nameWidth = max(nameWidth, len(license.Name))
	}
	p.Printf("%-*s  %-*s  %s\n", idWidth, "ID", nameWidth, "NAME", "URL")
	for _, license := range licenses {
		p.Printf("%-*s  %-*s  %s\n", idWidth, license.ID, nameWidth, license.Name, license.URL)
	}
}

func outputLicenseListJSON(p *printer, licenses []api.License) error {
	data, err := json.MarshalIndent(licenses, "", "  ")
	if err != nil {
		return err
	}
	p.Println(string(data))
	return nil
}

func newMODLicenseShowCommand(c *cli) *cobra.Command {
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "show <id>",
		Short: "Show a standard MOD Portal license identifier's details",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			id := args[0]
			p := c.printer(cmd)
			if !api.ValidLicenseIdentifier(id) {
				return invalidLicenseIdentifierError(p, id)
			}
			license, ok := api.StandardLicenseFor(id)
			if !ok {
				p.Error("Custom license identifiers have no fixed URL: " + id)
				p.Say("Look up the license text via the MOD Portal page for the MOD that uses it")
				return errors.New("Custom license identifiers have no fixed URL")
			}

			if jsonOutput {
				data, err := json.MarshalIndent(license, "", "  ")
				if err != nil {
					return err
				}
				p.Println(string(data))
				return nil
			}
			displayLicense(p, license)
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output in JSON format")
	return cmd
}

func displayLicense(p *printer, license api.License) {
	type row struct{ label, value string }
	rows := []row{
		{"ID", license.ID},
		{"Name", license.Name},
		{"Title", license.Title},
		{"Description", license.Description},
		{"URL", license.URL},
	}
	width := 0
	for _, r := range rows {
		width = max(width, len(r.label))
	}
	for _, r := range rows {
		p.Printf("%-*s  %s\n", width, r.label, r.value)
	}
}

// invalidLicenseIdentifierError reports and returns the standard error for
// an unrecognized --license/license-identifier value; shared by mod edit
// and mod license show.
func invalidLicenseIdentifierError(p *printer, id string) error {
	p.Error("Invalid license identifier: " + id)
	p.Say("Valid identifiers: " + strings.Join(api.LicenseIdentifiers(), ", "))
	p.Say("Custom licenses: custom_<24 hex chars> (e.g., custom_0123456789abcdef01234567)")
	return errors.New("Invalid license identifier")
}
