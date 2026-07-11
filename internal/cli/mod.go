package cli

import (
	"github.com/spf13/cobra"
)

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
		newMODSyncCommand(c),
		newMODUploadCommand(c),
		newMODEditCommand(c),
		newMODChangelogCommand(c),
		newMODImageCommand(c),
	)

	return mod
}
