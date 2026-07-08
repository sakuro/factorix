package cli

import (
	"bytes"
	"encoding/json"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/platform"
)

// pathEntries lists the displayed paths in output order.
var pathEntries = []struct {
	key      string
	resolver func(*platform.Runtime) (string, error)
}{
	{"executable_path", (*platform.Runtime).ExecutablePath},
	{"data_dir", (*platform.Runtime).DataDir},
	{"user_dir", (*platform.Runtime).UserDir},
	{"mod_dir", (*platform.Runtime).MODDir},
	{"save_dir", (*platform.Runtime).SaveDir},
	{"script_output_dir", (*platform.Runtime).ScriptOutputDir},
	{"mod_list_path", (*platform.Runtime).MODListPath},
	{"mod_settings_path", (*platform.Runtime).MODSettingsPath},
	{"player_data_path", (*platform.Runtime).PlayerDataPath},
	{"lock_path", (*platform.Runtime).LockPath},
	{"current_log_path", (*platform.Runtime).CurrentLogPath},
	{"previous_log_path", (*platform.Runtime).PreviousLogPath},
	{"factorix_cache_dir", (*platform.Runtime).FactorixCacheDir},
	{"factorix_config_path", (*platform.Runtime).FactorixConfigPath},
	{"factorix_log_path", (*platform.Runtime).FactorixLogPath},
}

func newPathCommand(c *cli) *cobra.Command {
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "path",
		Short: "Display Factorio and Factorix paths",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}

			keyWidth := 0
			values := make([]string, len(pathEntries))
			for i, entry := range pathEntries {
				value, err := entry.resolver(application.Runtime)
				if err != nil {
					return err
				}
				values[i] = value
				keyWidth = max(keyWidth, len(entry.key))
			}

			p := c.printer(cmd)
			if jsonOutput {
				var buf bytes.Buffer
				buf.WriteString("{\n")
				for i, entry := range pathEntries {
					key, _ := json.Marshal(entry.key)
					value, _ := json.Marshal(values[i])
					fmt.Fprintf(&buf, "  %s: %s", key, value)
					if i < len(pathEntries)-1 {
						buf.WriteString(",")
					}
					buf.WriteString("\n")
				}
				buf.WriteString("}")
				p.Println(buf.String())
				return nil
			}

			for i, entry := range pathEntries {
				p.Printf("%-*s  %s\n", keyWidth, entry.key, values[i])
			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output in JSON format")
	return cmd
}
