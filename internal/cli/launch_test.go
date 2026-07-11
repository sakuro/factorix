package cli

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// writeFakeFactorio installs a shell script at the sandbox's
// executable_path that appends its arguments to args.txt and then runs the
// given extra script body.
func writeFakeFactorio(t *testing.T, s *sandbox, body string) string {
	t.Helper()
	exePath := filepath.Join(s.root, "factorio", "bin", "x64", "factorio")
	require.NoError(t, os.MkdirAll(filepath.Dir(exePath), 0o755))
	script := "#!/bin/sh\necho \"$@\" >> \"" + filepath.Join(s.root, "args.txt") + "\"\n" + body
	require.NoError(t, os.WriteFile(exePath, []byte(script), 0o755))
	return filepath.Join(s.root, "args.txt")
}

func waitForFile(t *testing.T, path string) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(path); err == nil {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("file %s did not appear", path)
}

func TestLaunchSynchronousOption(t *testing.T) {
	s := newSandbox(t)
	argsPath := writeFakeFactorio(t, s, "")

	out, err := runCLI(t, "launch", "--", "--version")
	require.NoError(t, err)
	assert.Empty(t, out)

	// --version is synchronous, so the game has already run.
	data, err := os.ReadFile(argsPath)
	require.NoError(t, err)
	assert.Equal(t, "--version\n", string(data))
}

func TestLaunchAsync(t *testing.T) {
	s := newSandbox(t)
	argsPath := writeFakeFactorio(t, s, "")

	out, err := runCLI(t, "launch", "--", "--benchmark", "save.zip")
	require.NoError(t, err)
	assert.Empty(t, out)

	// Detached: the invocation returns before the game does, so poll.
	waitForFile(t, argsPath)
	data, err := os.ReadFile(argsPath)
	require.NoError(t, err)
	assert.Equal(t, "--benchmark save.zip\n", string(data))
}

func TestLaunchWait(t *testing.T) {
	s := newSandbox(t)
	lockPath := filepath.Join(s.root, "factorio", ".lock")
	// The fake game holds the lock briefly, like a daemonized Factorio.
	writeFakeFactorio(t, s, "touch \""+lockPath+"\"\nsleep 0.2\nrm \""+lockPath+"\"\n")

	original := launchPollInterval
	launchPollInterval = 10 * time.Millisecond
	t.Cleanup(func() { launchPollInterval = original })

	_, err := runCLI(t, "launch", "--wait")
	require.NoError(t, err)
	assert.NoFileExists(t, lockPath, "wait must return only after the lock is gone")
}

func TestLaunchRequiresGameStopped(t *testing.T) {
	s := newSandbox(t)
	writeFakeFactorio(t, s, "")
	require.NoError(t, os.WriteFile(filepath.Join(s.root, "factorio", ".lock"), nil, 0o644))

	_, err := runCLI(t, "launch")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "running")
}
