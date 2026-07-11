package cli

import (
	"io"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/rcon"
)

// factorioSentinelCommand is the no-op console command used to mark the end
// of fragmented RCON responses.
const factorioSentinelCommand = "/c"

func newRConCommand(c *cli) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "rcon",
		Short: "Interact with a running Factorio server via RCON",
	}
	cmd.AddCommand(newRConExecCommand(c), newRConEvalCommand(c))
	return cmd
}

// rconFlags holds the connection overrides shared by exec and eval; config
// values fill whatever the flags leave unset.
type rconFlags struct {
	host     string
	port     int
	password string
}

func (f *rconFlags) register(cmd *cobra.Command) {
	cmd.Flags().StringVar(&f.host, "host", "", "RCon host")
	cmd.Flags().IntVar(&f.port, "port", 0, "RCon port")
	cmd.Flags().StringVar(&f.password, "password", "", "RCon password")
}

// runRConCommand connects using flags-over-config settings, executes the
// command, and prints a non-empty response.
func runRConCommand(cmd *cobra.Command, c *cli, flags *rconFlags, command string) error {
	application, err := c.App()
	if err != nil {
		return err
	}
	host := flags.host
	if host == "" {
		host = application.Config.RCON.Host
	}
	port := flags.port
	if port == 0 {
		port = application.Config.RCON.Port
	}
	password := flags.password
	if password == "" {
		password = application.Config.RCON.Password
	}

	client, err := rcon.Dial(cmd.Context(), host, port, password, factorioSentinelCommand)
	if err != nil {
		return err
	}
	defer client.Close()

	result, err := client.Execute(command)
	if err != nil {
		return err
	}
	if result != "" {
		c.printer(cmd).Say(result)
	}
	return nil
}

func newRConExecCommand(c *cli) *cobra.Command {
	flags := &rconFlags{}
	cmd := &cobra.Command{
		Use:   "exec <command>",
		Short: "Execute a Factorio console command via RCon",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return runRConCommand(cmd, c, flags, args[0])
		},
	}
	flags.register(cmd)
	return cmd
}

func newRConEvalCommand(c *cli) *cobra.Command {
	flags := &rconFlags{}
	cmd := &cobra.Command{
		Use:   "eval [script]",
		Short: "Evaluate a Lua script in Factorio via RCon",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			var script string
			if len(args) > 0 {
				script = args[0]
			} else {
				data, err := io.ReadAll(cmd.InOrStdin())
				if err != nil {
					return err
				}
				script = string(data)
			}
			return runRConCommand(cmd, c, flags, "/c "+script)
		},
	}
	flags.register(cmd)
	return cmd
}
