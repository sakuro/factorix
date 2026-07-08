// Package logging sets up the application logger (log/slog) writing to the
// platform log path.
package logging

import (
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
)

// LevelFatal extends the slog levels with the "fatal" setting accepted by
// the Ruby implementation.
const LevelFatal = slog.LevelError + 4

// ParseLevel maps a log_level configuration value to a slog level.
func ParseLevel(s string) (slog.Level, error) {
	switch s {
	case "debug":
		return slog.LevelDebug, nil
	case "info":
		return slog.LevelInfo, nil
	case "warn":
		return slog.LevelWarn, nil
	case "error":
		return slog.LevelError, nil
	case "fatal":
		return LevelFatal, nil
	default:
		return 0, fmt.Errorf("invalid log level: %q", s)
	}
}

// NewFileLogger opens (creating directories as needed) the log file in
// append mode and returns a logger writing to it. The caller closes the
// returned Closer on shutdown.
func NewFileLogger(path string, level slog.Level) (*slog.Logger, io.Closer, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, nil, err
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		return nil, nil, err
	}
	logger := slog.New(slog.NewTextHandler(f, &slog.HandlerOptions{Level: level}))
	return logger, f, nil
}
