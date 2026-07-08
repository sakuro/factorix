package cli

import (
	"errors"
	"fmt"

	"github.com/spf13/cobra"
)

var errValidationFailed = errors.New("MOD dependency validation failed")

func newMODCheckCommand(c *cli) *cobra.Command {
	return &cobra.Command{
		Use:   "check",
		Short: "Validate MOD dependencies",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}
			state, err := loadMODState(application)
			if err != nil {
				return err
			}

			p := c.printer(cmd)
			result := state.validation
			p.Info("Validating MOD dependencies...")

			if result.Valid() && len(result.Warnings) == 0 {
				p.Success("All enabled MOD(s) have their required dependencies satisfied")
				p.Success("No circular dependencies detected")
				p.Success("No conflicting MOD(s) are enabled simultaneously")
			}
			if len(result.Warnings) > 0 {
				p.Warn("Warnings:")
				for _, warning := range result.Warnings {
					p.Say("  - " + warning.Message)
				}
			}
			if len(result.Errors) > 0 {
				p.Error("Errors:")
				for _, validationErr := range result.Errors {
					p.Say("  - " + validationErr.Message)
				}
			}
			if len(result.Suggestions) > 0 {
				p.Info("Suggestions:")
				for _, suggestion := range result.Suggestions {
					p.Say("  - " + suggestion.Message)
				}
			}

			enabledCount := 0
			for _, node := range state.graph.Nodes() {
				if node.Enabled {
					enabledCount++
				}
			}
			parts := fmt.Sprintf("%d enabled MOD%s", enabledCount, pluralSuffix(enabledCount))
			if n := len(result.Errors); n > 0 {
				parts += fmt.Sprintf(", %d error%s", n, pluralSuffix(n))
			}
			if n := len(result.Warnings); n > 0 {
				parts += fmt.Sprintf(", %d warning%s", n, pluralSuffix(n))
			}
			p.Info("Summary: " + parts)

			if !result.Valid() {
				return errValidationFailed
			}
			return nil
		},
	}
}

func pluralSuffix(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}
