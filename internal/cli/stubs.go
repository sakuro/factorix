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

func newLaunchCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "launch",
		Short: "Launch Factorio",
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
	)
	for _, use := range []string{"install", "uninstall", "update", "upload", "edit", "sync"} {
		mod.AddCommand(&cobra.Command{Use: use, Short: "MOD " + use, RunE: notImplemented})
	}

	changelog := &cobra.Command{Use: "changelog", Short: "Manage MOD changelogs"}
	for _, use := range []string{"add", "check", "extract", "release"} {
		changelog.AddCommand(&cobra.Command{Use: use, Short: "Changelog " + use, RunE: notImplemented})
	}
	mod.AddCommand(changelog)

	image := &cobra.Command{Use: "image", Short: "Manage MOD images"}
	for _, use := range []string{"list", "add", "edit"} {
		image.AddCommand(&cobra.Command{Use: use, Short: "Image " + use, RunE: notImplemented})
	}
	mod.AddCommand(image)

	return mod
}

func newCacheCommand() *cobra.Command {
	cache := &cobra.Command{
		Use:   "cache",
		Short: "Manage caches",
	}
	cache.AddCommand(
		&cobra.Command{Use: "stat", Short: "Show cache statistics", RunE: notImplemented},
		&cobra.Command{Use: "evict", Short: "Clear cache entries", RunE: notImplemented},
	)
	return cache
}

func newBlueprintCommand() *cobra.Command {
	blueprint := &cobra.Command{
		Use:   "blueprint",
		Short: "Encode and decode blueprint strings",
	}
	blueprint.AddCommand(
		&cobra.Command{Use: "encode", Short: "Encode JSON to a blueprint string", RunE: notImplemented},
		&cobra.Command{Use: "decode", Short: "Decode a blueprint string to JSON", RunE: notImplemented},
	)
	return blueprint
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
