package cli

import (
	"io"
	"os"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/settings"
)

const backupExtension = ".bak"

func newMODSettingsCommand(c *cli) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "settings",
		Short: "Manage MOD settings",
	}
	cmd.AddCommand(newMODSettingsDumpCommand(c), newMODSettingsRestoreCommand(c))
	return cmd
}

func newMODSettingsDumpCommand(c *cli) *cobra.Command {
	var output string

	cmd := &cobra.Command{
		Use:   "dump [settings_file]",
		Short: "Dump MOD settings to JSON format",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			settingsPath, err := settingsPathFromArgs(c, args)
			if err != nil {
				return err
			}
			modSettings, err := settings.LoadFile(settingsPath)
			if err != nil {
				return err
			}
			data, err := modSettings.DumpJSON()
			if err != nil {
				return err
			}

			if output != "" {
				return os.WriteFile(output, data, 0o644)
			}
			c.printer(cmd).Println(string(data))
			return nil
		},
	}
	cmd.Flags().StringVarP(&output, "output", "o", "", "Output file path")
	return cmd
}

func newMODSettingsRestoreCommand(c *cli) *cobra.Command {
	var input string

	cmd := &cobra.Command{
		Use:   "restore [settings_file]",
		Short: "Restore MOD settings from JSON format",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}
			if err := application.RequireGameStopped(); err != nil {
				return err
			}

			var data []byte
			if input != "" {
				data, err = os.ReadFile(input)
			} else {
				data, err = io.ReadAll(cmd.InOrStdin())
			}
			if err != nil {
				return err
			}

			modSettings, err := settings.RestoreJSON(data)
			if err != nil {
				return err
			}

			settingsPath, err := settingsPathFromArgs(c, args)
			if err != nil {
				return err
			}
			if err := backupIfExists(settingsPath); err != nil {
				return err
			}
			return modSettings.SaveFile(settingsPath)
		},
	}
	cmd.Flags().StringVarP(&input, "input", "i", "", "Input file path")
	return cmd
}

func settingsPathFromArgs(c *cli, args []string) (string, error) {
	if len(args) > 0 {
		return args[0], nil
	}
	application, err := c.App()
	if err != nil {
		return "", err
	}
	return application.Runtime.MODSettingsPath()
}

// backupIfExists renames an existing file to <path>.bak before overwriting.
func backupIfExists(path string) error {
	if _, err := os.Stat(path); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	return os.Rename(path, path+backupExtension)
}
