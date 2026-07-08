package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

func newMODDisableCommand(c *cli) *cobra.Command {
	var yes, all bool

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

			p := c.printer(cmd)
			var targets []mod.MOD
			if all {
				targets = dependency.PlanDisableAll(state.graph)
			} else {
				for _, name := range args {
					m := mod.MOD{Name: name}
					if m.IsBase() {
						return fmt.Errorf("%w: %s", mod.ErrCannotDisableBaseMOD, m)
					}
					if !state.graph.Contains(m) {
						p.Warn("MOD not installed, skipping: " + m.String())
					}
					targets = append(targets, m)
				}
			}

			planned := dependency.PlanDisable(state.graph, targets)

			if len(planned) == 0 {
				p.Info("All specified MOD(s) are already disabled")
				return nil
			}
			p.Info(fmt.Sprintf("Planning to disable %d MOD(s):", len(planned)))
			for _, m := range planned {
				p.Say("  - " + m.String())
			}

			confirmed, err := confirm(cmd, c.quiet, yes, "Do you want to disable these MOD(s)?")
			if err != nil {
				return err
			}
			if !confirmed {
				return nil
			}

			return applyMODListChange(cmd, c, application, state, planned, "Disabled", (*mod.MODList).Disable)
		},
	}
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompts")
	cmd.Flags().BoolVar(&all, "all", false, "Disable all MOD(s) (except base)")
	return cmd
}
