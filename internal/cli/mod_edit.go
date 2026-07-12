package cli

import (
	"errors"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/api"
)

func newMODEditCommand(c *cli) *cobra.Command {
	var metadata api.EditMetadata
	var deprecated bool

	cmd := &cobra.Command{
		Use:   "edit <mod-name>",
		Short: "Edit MOD metadata on Factorio MOD Portal",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			p := c.printer(cmd)
			if metadata.License != "" && !api.ValidLicenseIdentifier(metadata.License) {
				return invalidLicenseIdentifierError(p, metadata.License)
			}

			if cmd.Flags().Changed("deprecated") {
				metadata.Deprecated = &deprecated
			}
			if isEmptyEditMetadata(metadata) {
				p.Error("At least one metadata option must be provided")
				p.Say("Available options: --description, --summary, --title, --category, --tags, --license, --homepage, --source-url, --faq, --deprecated")
				return errors.New("No metadata options provided")
			}

			application, err := c.App()
			if err != nil {
				return err
			}
			management, err := application.ManagementAPI()
			if err != nil {
				return err
			}
			if err := management.EditDetails(cmd.Context(), args[0], metadata); err != nil {
				return err
			}
			p.Success("Metadata updated successfully!")
			return nil
		},
	}
	cmd.Flags().StringVar(&metadata.Description, "description", "", "Markdown description")
	cmd.Flags().StringVar(&metadata.Summary, "summary", "", "Brief description")
	cmd.Flags().StringVar(&metadata.Title, "title", "", "MOD title")
	cmd.Flags().StringVar(&metadata.Category, "category", "", "MOD category")
	cmd.Flags().StringSliceVar(&metadata.Tags, "tags", nil, "Array of tags")
	cmd.Flags().StringVar(&metadata.License, "license", "", "License identifier")
	cmd.Flags().StringVar(&metadata.Homepage, "homepage", "", "Homepage URL")
	cmd.Flags().StringVar(&metadata.SourceURL, "source-url", "", "Repository URL")
	cmd.Flags().StringVar(&metadata.FAQ, "faq", "", "FAQ text")
	cmd.Flags().BoolVar(&deprecated, "deprecated", false, "Deprecation flag")
	return cmd
}

func isEmptyEditMetadata(m api.EditMetadata) bool {
	return m.Description == "" && m.Summary == "" && m.Title == "" && m.Category == "" &&
		len(m.Tags) == 0 && m.License == "" && m.Homepage == "" && m.SourceURL == "" &&
		m.FAQ == "" && m.Deprecated == nil
}
