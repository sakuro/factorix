package cli

import (
	"errors"

	"github.com/spf13/cobra"
)

// errNotImplemented marks commands scheduled for later phases of the Go
// migration (see doc/go-migration-roadmap.md).
var errNotImplemented = errors.New("not implemented yet")

func notImplemented(cmd *cobra.Command, _ []string) error {
	return errNotImplemented
}

func newMODCommand(c *cli) *cobra.Command {
	mod := &cobra.Command{
		Use:   "mod",
		Short: "Manage MODs",
	}
	mod.AddCommand(
		newMODListCommand(c),
		newMODCheckCommand(c),
		newMODSettingsCommand(c),
		newMODEnableCommand(c),
		newMODDisableCommand(c),
		newMODSearchCommand(c),
		newMODShowCommand(c),
		newMODDownloadCommand(c),
		newMODInstallCommand(c),
		newMODUninstallCommand(c),
		newMODUpdateCommand(c),
	)
	mod.AddCommand(
		newMODSyncCommand(c),
		newMODUploadCommand(c),
		newMODEditCommand(c),
		newMODChangelogCommand(c),
		newMODImageCommand(c),
	)

	return mod
}
