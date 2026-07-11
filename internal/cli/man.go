package cli

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/spf13/cobra"

	factorix "github.com/sakuro/factorix"
)

func newManCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "man",
		Short: "Display the Factorix manual page",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			manPath, err := exec.LookPath("man")
			if err != nil {
				return fmt.Errorf("man command is not available on this system")
			}

			// The page ships inside the binary (single-binary distribution),
			// so materialize it for man.
			dir, err := os.MkdirTemp("", "factorix-man")
			if err != nil {
				return err
			}
			defer os.RemoveAll(dir)
			pagePath := filepath.Join(dir, "factorix.1")
			if err := os.WriteFile(pagePath, factorix.ManPage, 0o644); err != nil {
				return err
			}

			man := exec.CommandContext(cmd.Context(), manPath, pagePath)
			man.Stdin = os.Stdin
			man.Stdout = cmd.OutOrStdout()
			man.Stderr = cmd.ErrOrStderr()
			return man.Run()
		},
	}
}
