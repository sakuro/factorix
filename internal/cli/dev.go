package cli

import (
	"github.com/spf13/cobra"
)

func newDevCommand(c *cli) *cobra.Command {
	dev := &cobra.Command{
		Use:   "dev",
		Short: "MOD development and MOD Portal publishing commands",
	}
	dev.AddCommand(
		newDevUploadCommand(c),
		newDevEditCommand(c),
		newDevChangelogCommand(c),
		newDevImageCommand(c),
	)

	return dev
}
