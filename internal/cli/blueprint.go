package cli

import (
	"io"
	"os"
	"strings"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/blueprint"
)

func newBlueprintCommand(c *cli) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "blueprint",
		Short: "Encode and decode blueprint strings",
	}
	cmd.AddCommand(newBlueprintEncodeCommand(c), newBlueprintDecodeCommand(c))
	return cmd
}

func newBlueprintEncodeCommand(c *cli) *cobra.Command {
	var output string

	cmd := &cobra.Command{
		Use:   "encode [file]",
		Short: "Encode JSON to a Factorio blueprint string",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			data, err := readFileOrStdin(cmd, args)
			if err != nil {
				return err
			}
			bp, err := blueprint.FromJSON(data)
			if err != nil {
				return err
			}
			encoded, err := bp.Encode()
			if err != nil {
				return err
			}

			if output != "" {
				return os.WriteFile(output, []byte(encoded+"\n"), 0o644)
			}
			c.printer(cmd).Println(encoded)
			return nil
		},
	}
	cmd.Flags().StringVarP(&output, "output", "o", "", "Output file path (default: stdout)")
	return cmd
}

func newBlueprintDecodeCommand(c *cli) *cobra.Command {
	var output string

	cmd := &cobra.Command{
		Use:   "decode [file]",
		Short: "Decode a Factorio blueprint string to JSON",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			data, err := readFileOrStdin(cmd, args)
			if err != nil {
				return err
			}
			bp, err := blueprint.Decode(strings.TrimSpace(string(data)))
			if err != nil {
				return err
			}
			jsonData, err := bp.JSON()
			if err != nil {
				return err
			}

			if output != "" {
				return os.WriteFile(output, append(jsonData, '\n'), 0o644)
			}
			c.printer(cmd).Println(string(jsonData))
			return nil
		},
	}
	cmd.Flags().StringVarP(&output, "output", "o", "", "Output file path (default: stdout)")
	return cmd
}

// readFileOrStdin returns the contents of the file named by the optional
// positional argument, or all of stdin when the argument is absent.
func readFileOrStdin(cmd *cobra.Command, args []string) ([]byte, error) {
	if len(args) > 0 {
		return os.ReadFile(args[0])
	}
	return io.ReadAll(cmd.InOrStdin())
}
