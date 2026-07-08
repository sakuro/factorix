package cli

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"strings"

	"github.com/spf13/cobra"
)

var errConfirmRequiresYes = errors.New("cannot prompt for confirmation in quiet mode; use --yes to proceed automatically")

// confirm asks the user for a yes/no answer, matching Ruby's Confirmable
// mixin: --yes skips the prompt, quiet mode without --yes is an error (a
// suppressed prompt would otherwise hang or silently default), and only an
// explicit "y"/"yes" (case-insensitive) counts as yes — anything else,
// including EOF, is no.
func confirm(cmd *cobra.Command, quiet, yes bool, message string) (bool, error) {
	if yes {
		return true, nil
	}
	if quiet {
		return false, errConfirmRequiresYes
	}

	fmt.Fprintf(cmd.OutOrStdout(), "%s [y/N] ", message)
	line, err := bufio.NewReader(cmd.InOrStdin()).ReadString('\n')
	if err != nil && !errors.Is(err, io.EOF) {
		return false, err
	}
	response := strings.ToLower(strings.TrimSpace(line))
	return response == "y" || response == "yes", nil
}
