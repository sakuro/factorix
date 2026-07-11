package cli

import (
	"slices"
	"time"

	"github.com/spf13/cobra"
)

// Game options that print and exit without daemonizing; the launch waits
// for these instead of detaching.
var synchronousLaunchOptions = []string{
	"--dump-data",
	"--dump-icon-sprites",
	"--dump-prototype-locale",
	"--help",
	"--version",
}

// launchPollInterval is how often --wait polls the lock file; a variable so
// tests can shorten it.
var launchPollInterval = time.Second

func newLaunchCommand(c *cli) *cobra.Command {
	var wait bool

	cmd := &cobra.Command{
		Use:   "launch [-- <factorio-arg>...]",
		Short: "Launch Factorio game",
		Args:  cobra.ArbitraryArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}
			if err := application.RequireGameStopped(); err != nil {
				return err
			}

			async := !slices.ContainsFunc(args, func(arg string) bool {
				return slices.Contains(synchronousLaunchOptions, arg)
			})
			application.Logger.Info("Launching Factorio", "args", args)
			if err := application.Runtime.Launch(args, async); err != nil {
				return err
			}
			application.Logger.Info("Factorio launched successfully", "async", async)

			if !async || !wait {
				return nil
			}

			// Factorio double-forks, so the started process cannot be
			// waited on; poll the lock file instead: first until the game
			// has created it, then until it disappears.
			application.Logger.Debug("Waiting for game to start")
			if err := waitForRunningState(application.Runtime.IsRunning, true); err != nil {
				return err
			}
			application.Logger.Debug("Game started, waiting for termination")
			if err := waitForRunningState(application.Runtime.IsRunning, false); err != nil {
				return err
			}
			application.Logger.Info("Game terminated")
			return nil
		},
	}
	cmd.Flags().BoolVarP(&wait, "wait", "w", false, "Wait for the game to finish")
	return cmd
}

// waitForRunningState polls isRunning until it reports want.
func waitForRunningState(isRunning func() (bool, error), want bool) error {
	for {
		running, err := isRunning()
		if err != nil {
			return err
		}
		if running == want {
			return nil
		}
		time.Sleep(launchPollInterval)
	}
}
