package cli

import (
	"context"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

func newMODDisableCommand(c *cli) *cobra.Command {
	var yes, all bool
	var backupExtension string

	cmd := &cobra.Command{
		Use:   "disable [mod-name]...",
		Short: "Disable MOD(s) in mod-list.json (recursively disables dependent MOD(s))",
		Args:  cobra.ArbitraryArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if all && len(args) > 0 {
				return fmt.Errorf("Cannot specify MOD names with --all option")
			}
			if !all && len(args) == 0 {
				return fmt.Errorf("Must specify MOD names or use --all option")
			}

			opts := mutationOpts{
				yes:             yes,
				quiet:           c.quiet,
				backupExtension: backupExtension,
				confirmPrompt:   "Do you want to disable these MOD(s)?",
				emptyMessage:    "All specified MOD(s) are already disabled",
			}
			plan := func(ctx context.Context, application *app.App, state *modState) ([]mod.MOD, error) {
				p := c.printer(cmd)
				var targets []mod.MOD
				if all {
					targets = dependency.PlanDisableAll(state.graph)
				} else {
					for _, name := range args {
						m := mod.MOD{Name: name}
						if m.IsBase() {
							return nil, fmt.Errorf("%w: %s", mod.ErrCannotDisableBaseMOD, m)
						}
						if !state.graph.Contains(m) {
							p.Warn("MOD not installed, skipping: " + m.String())
						}
						targets = append(targets, m)
					}
				}
				return dependency.PlanDisable(state.graph, targets), nil
			}
			isEmpty := func(planned []mod.MOD) bool { return len(planned) == 0 }
			show := func(p *printer, planned []mod.MOD) {
				p.Info(fmt.Sprintf("Planning to disable %d MOD(s):", len(planned)))
				for _, m := range planned {
					p.Say("  - " + m.String())
				}
			}
			execute := func(ctx context.Context, application *app.App, state *modState, p *printer, planned []mod.MOD) error {
				for _, m := range planned {
					if err := state.modList.Disable(m); err != nil {
						return err
					}
					p.Success("Disabled " + m.String())
				}
				p.Success(fmt.Sprintf("Disabled %d MOD(s)", len(planned)))
				return nil
			}
			return runMODMutation(cmd, c, opts, plan, isEmpty, show, execute)
		},
	}
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().BoolVar(&all, "all", false, "Disable all MOD(s) (except base)")
	cmd.Flags().StringVar(&backupExtension, "backup-extension", defaultBackupExtension, "Backup file extension")
	return cmd
}
