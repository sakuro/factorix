// Package platform resolves Factorio and Factorix paths for each supported
// OS (Linux, macOS, Windows, WSL). Named platform rather than the stdlib
// name runtime, which it must import.
package platform

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// UnsupportedPlatformError reports an OS the tool does not support.
type UnsupportedPlatformError struct {
	GOOS string
}

func (e *UnsupportedPlatformError) Error() string {
	return "platform is not supported: " + e.GOOS
}

var ErrMissingEnv = errors.New("required environment variable is not set")

// Platform provides the platform-specific base paths. The Default* methods
// return the fallbacks used when the corresponding XDG_* environment
// variable is not set.
type Platform interface {
	GameExecutablePath() (string, error)
	GameUserDir() (string, error)
	GameDataDir() (string, error)
	DefaultCacheHomeDir() (string, error)
	DefaultConfigHomeDir() (string, error)
	DefaultDataHomeDir() (string, error)
	DefaultStateHomeDir() (string, error)
	DefaultFactorixLogPath() (string, error)
}

// Overrides are user-configured paths that take precedence over platform
// auto-detection (the [runtime] section of config.toml).
type Overrides struct {
	ExecutablePath string
	UserDir        string
	DataDir        string
}

// Runtime combines a Platform with user overrides and derives every path
// the application needs.
type Runtime struct {
	platform  Platform
	overrides Overrides
}

// NewRuntime wraps a platform with user overrides.
func NewRuntime(p Platform, o Overrides) *Runtime {
	return &Runtime{platform: p, overrides: o}
}

// ExecutablePath returns the Factorio executable path.
func (r *Runtime) ExecutablePath() (string, error) {
	if r.overrides.ExecutablePath != "" {
		return r.overrides.ExecutablePath, nil
	}
	return r.platform.GameExecutablePath()
}

// UserDir returns the Factorio user directory (mods, saves, config).
func (r *Runtime) UserDir() (string, error) {
	if r.overrides.UserDir != "" {
		return r.overrides.UserDir, nil
	}
	return r.platform.GameUserDir()
}

// DataDir returns the Factorio data directory (base game data and bundled
// expansion MODs).
func (r *Runtime) DataDir() (string, error) {
	if r.overrides.DataDir != "" {
		return r.overrides.DataDir, nil
	}
	return r.platform.GameDataDir()
}

func (r *Runtime) underUserDir(elems ...string) (string, error) {
	userDir, err := r.UserDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(append([]string{userDir}, elems...)...), nil
}

// MODDir returns the directory holding installed MODs and MOD configuration.
func (r *Runtime) MODDir() (string, error) {
	return r.underUserDir("mods")
}

// SaveDir returns the save game directory.
func (r *Runtime) SaveDir() (string, error) {
	return r.underUserDir("saves")
}

// ScriptOutputDir returns the directory for Lua script output.
func (r *Runtime) ScriptOutputDir() (string, error) {
	return r.underUserDir("script-output")
}

// MODListPath returns the path of mod-list.json.
func (r *Runtime) MODListPath() (string, error) {
	return r.underUserDir("mods", "mod-list.json")
}

// MODSettingsPath returns the path of mod-settings.dat.
func (r *Runtime) MODSettingsPath() (string, error) {
	return r.underUserDir("mods", "mod-settings.dat")
}

// PlayerDataPath returns the path of player-data.json.
func (r *Runtime) PlayerDataPath() (string, error) {
	return r.underUserDir("player-data.json")
}

// CurrentLogPath returns the path of the current Factorio log.
func (r *Runtime) CurrentLogPath() (string, error) {
	return r.underUserDir("factorio-current.log")
}

// PreviousLogPath returns the path of the previous Factorio log.
func (r *Runtime) PreviousLogPath() (string, error) {
	return r.underUserDir("factorio-previous.log")
}

// LockPath returns the path of the lock file Factorio creates while running.
func (r *Runtime) LockPath() (string, error) {
	return r.underUserDir(".lock")
}

// IsRunning reports whether Factorio is running. The game daemonizes on
// launch, so the lock file is the only reliable signal.
func (r *Runtime) IsRunning() (bool, error) {
	lockPath, err := r.LockPath()
	if err != nil {
		return false, err
	}
	_, err = os.Stat(lockPath)
	if err == nil {
		return true, nil
	}
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	return false, err
}

// Launch starts Factorio with the given arguments. Factorio daemonizes
// itself (double fork), so the direct child is not the game: async starts
// it and returns immediately (stdout discarded, as in Ruby's spawn with
// out: IO::NULL); synchronous waits for the direct child with inherited
// stdio — meaningful only for non-daemonizing options like --help — and
// ignores its exit status, as Ruby's system does.
func (r *Runtime) Launch(args []string, async bool) error {
	exe, err := r.ExecutablePath()
	if err != nil {
		return err
	}
	cmd := exec.Command(exe, args...)
	// Ruby launches with argv[0] set to "factorio"; keep that visible name.
	cmd.Args = append([]string{"factorio"}, args...)

	if async {
		cmd.Stderr = os.Stderr
		if err := cmd.Start(); err != nil {
			return err
		}
		return cmd.Process.Release()
	}

	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return nil
		}
		return err
	}
	return nil
}

// xdgDir returns the environment variable's value when set (even if empty,
// matching the Ruby ENV.fetch behavior), otherwise the platform default.
func xdgDir(envVar string, defaultFn func() (string, error)) (string, error) {
	if value, ok := os.LookupEnv(envVar); ok {
		return value, nil
	}
	return defaultFn()
}

// XDGCacheHomeDir returns XDG_CACHE_HOME or the platform equivalent.
func (r *Runtime) XDGCacheHomeDir() (string, error) {
	return xdgDir("XDG_CACHE_HOME", r.platform.DefaultCacheHomeDir)
}

// XDGConfigHomeDir returns XDG_CONFIG_HOME or the platform equivalent.
func (r *Runtime) XDGConfigHomeDir() (string, error) {
	return xdgDir("XDG_CONFIG_HOME", r.platform.DefaultConfigHomeDir)
}

// XDGDataHomeDir returns XDG_DATA_HOME or the platform equivalent.
func (r *Runtime) XDGDataHomeDir() (string, error) {
	return xdgDir("XDG_DATA_HOME", r.platform.DefaultDataHomeDir)
}

// XDGStateHomeDir returns XDG_STATE_HOME or the platform equivalent.
func (r *Runtime) XDGStateHomeDir() (string, error) {
	return xdgDir("XDG_STATE_HOME", r.platform.DefaultStateHomeDir)
}

// FactorixCacheDir returns the Factorix cache directory.
func (r *Runtime) FactorixCacheDir() (string, error) {
	dir, err := r.XDGCacheHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "factorix"), nil
}

// FactorixConfigPath returns the Factorix configuration file path.
func (r *Runtime) FactorixConfigPath() (string, error) {
	dir, err := r.XDGConfigHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "factorix", "config.toml"), nil
}

// FactorixLogPath returns the Factorix log file path. An explicitly set
// XDG_STATE_HOME takes precedence over the platform convention so sandboxed
// environments (tests) can redirect the log file.
func (r *Runtime) FactorixLogPath() (string, error) {
	if stateHome, ok := os.LookupEnv("XDG_STATE_HOME"); ok {
		return filepath.Join(stateHome, "factorix", "factorix.log"), nil
	}
	return r.platform.DefaultFactorixLogPath()
}

// homeDir returns the user's home directory.
func homeDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("cannot determine home directory: %w", err)
	}
	return home, nil
}

// homePath joins elems under the home directory.
func homePath(elems ...string) (string, error) {
	home, err := homeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(append([]string{home}, elems...)...), nil
}
