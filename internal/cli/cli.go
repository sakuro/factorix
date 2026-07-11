// Package cli defines the factorix command tree (cobra).
package cli

import (
	"sync"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/logging"
)

// Version is the factorix version, injected at build time by goreleaser.
var Version = "dev"

// cli carries the global flags and the lazily-built application.
type cli struct {
	configPath string
	logLevel   string
	quiet      bool

	// App builds the application on first use, memoized via sync.OnceValues;
	// commands like version never pay for config loading or log-file
	// creation. Set in NewRootCommand — the wrapped closure reads
	// configPath/logLevel at call time, by which point cobra has already
	// parsed the flags that set them.
	App func() (*app.App, error)

	// builtApp is set as a side effect the first time App succeeds, purely
	// so Close can tell "never built" from "built" without calling App
	// itself — calling App from Close would force construction (and thus
	// config loading, log-file creation) even for commands like version
	// that never touch the application.
	builtApp *app.App
}

func (c *cli) Close() {
	if c.builtApp != nil {
		_ = c.builtApp.Close()
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
	c.App = sync.OnceValues(func() (*app.App, error) {
		a, err := app.New(app.Options{ConfigPath: c.configPath, LogLevel: c.logLevel})
		if err == nil {
			c.builtApp = a
		}
		return a, err
	})

	root = &cobra.Command{
		Use:           "factorix",
		Short:         "Manage Factorio MODs, settings, and game control",
		SilenceUsage:  true,
		SilenceErrors: true,
		// Ruby validates --log-level values at option-parse time for every
		// command; checking only at app construction would let commands that
		// never build the app (like version) accept invalid values silently.
		PersistentPreRunE: func(*cobra.Command, []string) error {
			if c.logLevel == "" {
				return nil
			}
			_, err := logging.ParseLevel(c.logLevel)
			return err
		},
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
		newLaunchCommand(c),
		newManCommand(),
		newMODCommand(c),
		newCacheCommand(c),
		newBlueprintCommand(c),
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
