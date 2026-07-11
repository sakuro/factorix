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

func newDownloadCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "download",
		Short: "Download the game",
		RunE:  notImplemented,
	}
}

func newManCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "man",
		Short: "Display the manual page",
		RunE:  notImplemented,
	}
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

func newRConCommand() *cobra.Command {
	rcon := &cobra.Command{
		Use:   "rcon",
		Short: "Interact with a running Factorio server via RCON",
	}
	rcon.AddCommand(
		&cobra.Command{Use: "exec", Short: "Execute a console command", RunE: notImplemented},
		&cobra.Command{Use: "eval", Short: "Evaluate a Lua script", RunE: notImplemented},
	)
	return rcon
}
