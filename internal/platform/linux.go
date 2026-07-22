package platform

import (
	"fmt"
	"os"
	"path/filepath"
)

// Linux discovers the Steam installation via ~/.steam/steam (native/deb
// packages), falling back to the Flatpak equivalent, then locates
// Factorio inside whichever Steam library folder actually contains it.
// Other installations (standalone, Snap) are covered by the [runtime]
// overrides in config.toml.
type Linux struct{}

func (Linux) steamRoot() (string, error) {
	native, err := homePath(".steam", "steam")
	if err != nil {
		return "", err
	}
	if info, statErr := os.Stat(native); statErr == nil && info.IsDir() {
		return native, nil
	}

	flatpak, err := homePath(".var", "app", "com.valvesoftware.Steam", ".steam", "steam")
	if err != nil {
		return "", err
	}
	if info, statErr := os.Stat(flatpak); statErr == nil && info.IsDir() {
		return flatpak, nil
	}

	return "", fmt.Errorf("Steam installation not found (checked %s and %s)", native, flatpak)
}

func (l Linux) factorioDir() (string, error) {
	root, err := l.steamRoot()
	if err != nil {
		return "", err
	}
	return findFactorioDir(root)
}

func (l Linux) GameExecutablePath() (string, error) {
	factorioDir, err := l.factorioDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(factorioDir, "bin", "x64", "factorio"), nil
}

func (Linux) GameUserDir() (string, error) {
	return homePath(".factorio")
}

func (l Linux) GameDataDir() (string, error) {
	factorioDir, err := l.factorioDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(factorioDir, "data"), nil
}

func (Linux) DefaultCacheHomeDir() (string, error) {
	return homePath(".cache")
}

func (Linux) DefaultConfigHomeDir() (string, error) {
	return homePath(".config")
}

func (Linux) DefaultDataHomeDir() (string, error) {
	return homePath(".local", "share")
}

func (Linux) DefaultStateHomeDir() (string, error) {
	return homePath(".local", "state")
}

func (l Linux) DefaultFactorixLogPath() (string, error) {
	stateHome, err := l.DefaultStateHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(stateHome, "factorix", "factorix.log"), nil
}

// Name identifies the platform.
func (Linux) Name() string { return "Linux" }
