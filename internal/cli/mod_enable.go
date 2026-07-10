package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

func newMODEnableCommand(c *cli) *cobra.Command {
	var yes bool
	var backupExtension string

	cmd := &cobra.Command{
		Use:   "enable <mod-name>...",
		Short: "Enable MOD(s) in mod-list.json (recursively enables dependencies)",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}
			// Checked before any other work, matching Ruby's RequiresGameStopped
			// (an outer wrapper that runs before the command body).
			if err := application.RequireGameStopped(); err != nil {
				return err
			}

			state, err := loadMODState(application)
			if err != nil {
				return err
			}

			targets := make([]mod.MOD, len(args))
			for i, name := range args {
				targets[i] = mod.MOD{Name: name}
			}
			for _, m := range targets {
				if !state.graph.Contains(m) {
					return fmt.Errorf("MOD '%s' is not installed", m)
				}
			}

			planned, err := dependency.PlanEnable(state.graph, targets)
			if err != nil {
				return err
			}
			if err := dependency.ValidateNoConflicts(state.graph, planned); err != nil {
				return err
			}

			p := c.printer(cmd)
			if len(planned) == 0 {
				p.Info("All specified MOD(s) are already enabled")
				return nil
			}
			p.Info(fmt.Sprintf("Planning to enable %d MOD(s):", len(planned)))
			for _, m := range planned {
				p.Say("  - " + m.String())
			}

			confirmed, err := confirm(cmd, c.quiet, yes, "Do you want to enable these MOD(s)?")
			if err != nil {
				return err
			}
			if !confirmed {
				return nil
			}

			return applyMODListChange(cmd, c, application, state, planned, "Enabled", (*mod.MODList).Enable, backupExtension)
		},
	}
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().StringVar(&backupExtension, "backup-extension", defaultBackupExtension, "Backup file extension")
	return cmd
}

// applyMODListChange applies fn (MODList.Enable or MODList.Disable) to each
// MOD in planned, reporting success per MOD, then backs up and saves
// mod-list.json. This is the shared tail of the enable and disable commands.
func applyMODListChange(cmd *cobra.Command, c *cli, application *app.App, state *modState, planned []mod.MOD, verb string, fn func(*mod.MODList, mod.MOD) error, backupExtension string) error {
	p := c.printer(cmd)
	for _, m := range planned {
		if err := fn(state.modList, m); err != nil {
			return err
		}
		p.Success(verb + " " + m.String())
	}

	modListPath, err := application.Runtime.MODListPath()
	if err != nil {
		return err
	}
	if err := backupIfExists(modListPath, backupExtension); err != nil {
		return err
	}
	if err := state.modList.Save(modListPath); err != nil {
		return err
	}
	p.Success(fmt.Sprintf("%s %d MOD(s)", verb, len(planned)))
	p.Success("Saved mod-list.json")
	return nil
}
