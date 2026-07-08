// Command factorix is a CLI for Factorio MOD management, settings
// synchronization, and MOD Portal integration.
package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/sakuro/factorix/internal/cli"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	root, reportError := cli.NewRootCommand()
	if err := root.ExecuteContext(ctx); err != nil {
		reportError(err)
		os.Exit(1)
	}
}
