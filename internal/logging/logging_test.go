package logging

import (
	"log/slog"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParseLevel(t *testing.T) {
	tests := map[string]slog.Level{
		"debug": slog.LevelDebug,
		"info":  slog.LevelInfo,
		"warn":  slog.LevelWarn,
		"error": slog.LevelError,
		"fatal": LevelFatal,
	}
	for input, want := range tests {
		got, err := ParseLevel(input)
		require.NoError(t, err)
		assert.Equal(t, want, got)
	}

	_, err := ParseLevel("verbose")
	require.Error(t, err)
}

func TestNewFileLogger(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state", "factorix", "factorix.log")

	logger, closer, err := NewFileLogger(path, slog.LevelInfo)
	require.NoError(t, err)
	defer closer.Close()

	logger.Info("hello", "key", "value")
	logger.Debug("filtered out")
	require.NoError(t, closer.Close())

	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Contains(t, string(data), "hello")
	assert.Contains(t, string(data), "key=value")
	assert.NotContains(t, string(data), "filtered out")
}
