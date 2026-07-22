package platform

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
)

// Windows locates Factorio via the Steam registry key (read through
// PowerShell, consistent with WSL) and other paths via the standard
// environment variables. Other installations are covered by the
// [runtime] overrides in config.toml.
type Windows struct {
	steamRoot func() (string, error)
}

// NewWindows returns a Windows platform. The registry read behind
// steamRoot runs at most once, memoized via sync.OnceValues.
func NewWindows() *Windows {
	return &Windows{steamRoot: sync.OnceValues(fetchWindowsSteamPath)}
}

const windowsSteamPathScript = `(Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue).SteamPath`

func fetchWindowsSteamPath() (string, error) {
	out, err := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", windowsSteamPathScript).Output()
	if err != nil {
		return "", fmt.Errorf("PowerShell execution failed: %w", err)
	}
	path := strings.TrimSpace(string(out))
	if path == "" {
		return "", fmt.Errorf("%w: SteamPath", ErrMissingEnv)
	}
	return path, nil
}

func windowsEnv(name string) (string, error) {
	value := os.Getenv(name)
	if value == "" {
		return "", fmt.Errorf("%w: %s", ErrMissingEnv, name)
	}
	return value, nil
}

func (*Windows) appData() (string, error) {
	return windowsEnv("APPDATA")
}

func (*Windows) localAppData() (string, error) {
	return windowsEnv("LOCALAPPDATA")
}

func (w *Windows) factorioDir() (string, error) {
	root, err := w.steamRoot()
	if err != nil {
		return "", err
	}
	return findFactorioDir(root)
}

func (w *Windows) GameExecutablePath() (string, error) {
	factorioDir, err := w.factorioDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(factorioDir, "bin", "x64", "factorio.exe"), nil
}

func (w *Windows) GameUserDir() (string, error) {
	appData, err := w.appData()
	if err != nil {
		return "", err
	}
	return filepath.Join(appData, "Factorio"), nil
}

func (w *Windows) GameDataDir() (string, error) {
	factorioDir, err := w.factorioDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(factorioDir, "data"), nil
}

func (w *Windows) DefaultCacheHomeDir() (string, error) {
	return w.localAppData()
}

func (w *Windows) DefaultConfigHomeDir() (string, error) {
	return w.appData()
}

func (w *Windows) DefaultDataHomeDir() (string, error) {
	return w.localAppData()
}

func (*Windows) DefaultStateHomeDir() (string, error) {
	return homePath(".local", "state")
}

func (w *Windows) DefaultFactorixLogPath() (string, error) {
	stateHome, err := w.DefaultStateHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(stateHome, "factorix", "factorix.log"), nil
}

// Name identifies the platform.
func (*Windows) Name() string { return "Windows" }
