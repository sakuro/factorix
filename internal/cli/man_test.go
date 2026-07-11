package cli

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestManRendersEmbeddedPage(t *testing.T) {
	// A pipe (non-TTY) makes man render without a pager.
	out, err := runCLI(t, "man")
	require.NoError(t, err)
	assert.Contains(t, out, "factorix")
	assert.Contains(t, out, "User Commands")
}

func TestManCommandNotAvailable(t *testing.T) {
	t.Setenv("PATH", t.TempDir())
	_, err := runCLI(t, "man")
	require.Error(t, err)
	assert.Equal(t, "man command is not available on this system", err.Error())
}
