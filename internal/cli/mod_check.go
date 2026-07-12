package cli

import (
	"errors"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/dependency"
)

var errValidationFailed = errors.New("MOD dependency validation failed")

func newMODCheckCommand(c *cli) *cobra.Command {
	var ignoreRecommended bool

	cmd := &cobra.Command{
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
			if ignoreRecommended {
				result = withoutRecommendedWarnings(result)
			}
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
	cmd.Flags().BoolVar(&ignoreRecommended, "ignore-recommended", false, "Do not warn about disabled recommended dependencies")
	return cmd
}

// withoutRecommendedWarnings returns a copy of result with
// WarningRecommendedDependencyDisabled entries removed, leaving the
// original untouched.
func withoutRecommendedWarnings(result *dependency.ValidationResult) *dependency.ValidationResult {
	filtered := make([]dependency.ValidationWarning, 0, len(result.Warnings))
	for _, w := range result.Warnings {
		if w.Type != dependency.WarningRecommendedDependencyDisabled {
			filtered = append(filtered, w)
		}
	}
	return &dependency.ValidationResult{Errors: result.Errors, Warnings: filtered, Suggestions: result.Suggestions}
}

func pluralSuffix(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}
