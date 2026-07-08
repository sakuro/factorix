// Package cli defines the factorix command tree (cobra).
package cli

import (
	"sync"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
)

// Version is the factorix version, injected at build time by goreleaser.
var Version = "dev"

// cli carries the global flags and the lazily-built application.
type cli struct {
	configPath string
	logLevel   string
	quiet      bool

	appOnce sync.Once
	app     *app.App
	appErr  error
}

// App builds the application on first use; commands like version never pay
// for config loading or log-file creation.
func (c *cli) App() (*app.App, error) {
	c.appOnce.Do(func() {
		c.app, c.appErr = app.New(app.Options{ConfigPath: c.configPath, LogLevel: c.logLevel})
	})
	return c.app, c.appErr
}

func (c *cli) Close() {
	if c.app != nil {
		_ = c.app.Close()
	}
}

func (c *cli) printer(cmd *cobra.Command) *printer {
	return &printer{out: cmd.OutOrStdout(), quiet: c.quiet}
}

// NewRootCommand builds the factorix root command with all subcommands.
// The returned reportError func prints a command's returned error the way
// each Ruby command does it internally (respecting --quiet and NO_COLOR)
// before the process exits; call it only when Execute returns a non-nil
// error.
func NewRootCommand() (root *cobra.Command, reportError func(error)) {
	c := &cli{}

	root = &cobra.Command{
		Use:           "factorix",
		Short:         "Manage Factorio MODs, settings, and game control",
		SilenceUsage:  true,
		SilenceErrors: true,
		PersistentPostRun: func(*cobra.Command, []string) {
			c.Close()
		},
	}

	root.PersistentFlags().StringVarP(&c.configPath, "config-path", "c", "", "Path to configuration file")
	root.PersistentFlags().StringVar(&c.logLevel, "log-level", "", "Set log level (debug, info, warn, error, fatal)")
	root.PersistentFlags().BoolVarP(&c.quiet, "quiet", "q", false, "Suppress non-essential output")

	root.AddCommand(
		newVersionCommand(),
		newPathCommand(c),
		newDownloadCommand(),
		newLaunchCommand(),
		newManCommand(),
		newMODCommand(c),
		newCacheCommand(),
		newBlueprintCommand(),
		newRConCommand(),
	)

	reportError = func(err error) {
		if c.quiet {
			return
		}
		c.printer(root).Error("Error: " + err.Error())
	}
	return root, reportError
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
