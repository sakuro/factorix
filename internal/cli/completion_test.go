package cli

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Completion is cobra's built-in command; the scripts are generated from
// the live command tree (unlike Ruby's hand-written completion/ scripts).
func TestCompletionGeneratesScripts(t *testing.T) {
	for shell, marker := range map[string]string{
		"bash": "factorix",
		"fish": "complete",
		"zsh":  "#compdef factorix",
	} {
		out, err := runCLI(t, "completion", shell)
		require.NoError(t, err, shell)
		assert.Contains(t, out, marker, shell)
	}
}
