package cli

import (
	"context"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

func newMODEnableCommand(c *cli) *cobra.Command {
	var yes, ignoreRecommended bool
	var backupExtension string

	cmd := &cobra.Command{
		Use:   "enable <mod-name>...",
		Short: "Enable MOD(s) in mod-list.json (recursively enables dependencies)",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			opts := mutationOpts{
				yes:             yes,
				quiet:           c.quiet,
				backupExtension: backupExtension,
				confirmPrompt:   "Do you want to enable these MOD(s)?",
				emptyMessage:    "All specified MOD(s) are already enabled",
			}
			plan := func(ctx context.Context, application *app.App, state *modState) ([]mod.MOD, error) {
				targets := make([]mod.MOD, len(args))
				for i, name := range args {
					targets[i] = mod.MOD{Name: name}
				}
				for _, m := range targets {
					if !state.graph.Contains(m) {
						return nil, fmt.Errorf("MOD '%s' is not installed", m)
					}
				}

				planned, err := dependency.PlanEnable(state.graph, targets, !ignoreRecommended)
				if err != nil {
					return nil, err
				}
				if err := dependency.ValidateNoConflicts(state.graph, planned); err != nil {
					return nil, err
				}
				return planned, nil
			}
			isEmpty := func(planned []mod.MOD) bool { return len(planned) == 0 }
			show := func(p *printer, planned []mod.MOD) {
				p.Info(fmt.Sprintf("Planning to enable %d MOD(s):", len(planned)))
				for _, m := range planned {
					p.Say("  - " + m.String())
				}
			}
			execute := func(ctx context.Context, application *app.App, state *modState, p *printer, planned []mod.MOD) error {
				for _, m := range planned {
					if err := state.modList.Enable(m); err != nil {
						return err
					}
					p.Success("Enabled " + m.String())
				}
				p.Success(fmt.Sprintf("Enabled %d MOD(s)", len(planned)))
				return nil
			}
			return runMODMutation(cmd, c, opts, plan, isEmpty, show, execute)
		},
	}
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().BoolVar(&ignoreRecommended, "ignore-recommended", false, "Do not enable recommended dependencies")
	cmd.Flags().StringVar(&backupExtension, "backup-extension", defaultBackupExtension, "Backup file extension")
	return cmd
}
