// Package cli defines the factorix command tree (cobra).
package cli

import (
	"github.com/spf13/cobra"
)

// Version is the factorix version, injected at build time by goreleaser.
var Version = "dev"

// NewRootCommand builds the factorix root command with all subcommands.
func NewRootCommand() *cobra.Command {
	root := &cobra.Command{
		Use:           "factorix",
		Short:         "Manage Factorio MODs, settings, and game control",
		SilenceUsage:  true,
		SilenceErrors: true,
	}

	root.PersistentFlags().StringP("config-path", "c", "", "Path to configuration file")
	root.PersistentFlags().String("log-level", "", "Set log level (debug, info, warn, error, fatal)")
	root.PersistentFlags().BoolP("quiet", "q", false, "Suppress non-essential output")

	root.AddCommand(
		newVersionCommand(),
		newPathCommand(),
		newDownloadCommand(),
		newLaunchCommand(),
		newManCommand(),
		newMODCommand(),
		newCacheCommand(),
		newBlueprintCommand(),
		newRConCommand(),
	)

	return root
}

func newVersionCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "Display Factorix version",
		RunE: func(cmd *cobra.Command, _ []string) error {
			cmd.Println(Version)
			return nil
		},
	}
}
