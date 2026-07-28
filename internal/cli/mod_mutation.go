package cli

import (
	"context"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
)

// mutationOpts configures runMODMutation's confirmation and persistence
// behavior; the strings and flags a command's own cobra flags feed in.
type mutationOpts struct {
	yes             bool
	quiet           bool
	backupExtension string
	confirmPrompt   string
	emptyMessage    string
}

// runMODMutation implements the shared skeleton behind the MOD-list
// mutation commands (install, uninstall, enable, disable, update):
// RequireGameStopped, load state, plan, bail out on an empty plan, show
// the plan, confirm, execute, then back up and save mod-list.json.
// execute is responsible for any command-specific summary message; this
// function only prints the final "Saved mod-list.json".
func runMODMutation[P any](
	cmd *cobra.Command, c *cli, opts mutationOpts,
	plan func(ctx context.Context, application *app.App, state *modState) (P, error),
	isEmpty func(P) bool,
	show func(p *printer, plan P),
	execute func(ctx context.Context, application *app.App, state *modState, p *printer, plan P) error,
) error {
	application, err := c.App()
	if err != nil {
		return err
	}
	if err := application.RequireGameStopped(); err != nil {
		return err
	}

	state, err := loadMODState(application)
	if err != nil {
		return err
	}

	planned, err := plan(cmd.Context(), application, state)
	if err != nil {
		return err
	}

	p := c.printer(cmd)
	if isEmpty(planned) {
		p.Info(opts.emptyMessage)
		return nil
	}

	show(p, planned)

	confirmed, err := confirm(cmd, opts.quiet, opts.yes, opts.confirmPrompt)
	if err != nil {
		return err
	}
	if !confirmed {
		return nil
	}

	if err := execute(cmd.Context(), application, state, p, planned); err != nil {
		return err
	}

	modListPath, err := application.Runtime.MODListPath()
	if err != nil {
		return err
	}
	if err := backupIfExists(modListPath, opts.backupExtension); err != nil {
		return err
	}
	if err := state.modList.Save(modListPath); err != nil {
		return err
	}
	p.Success("Saved mod-list.json")
	return nil
}
