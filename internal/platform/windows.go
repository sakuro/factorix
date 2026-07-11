package platform

import (
	"fmt"
	"os"
	"path/filepath"
)

// Windows locates Factorio via the standard environment variables and
// assumes a Steam installation; other installations are covered by the
// [runtime] overrides in config.toml.
type Windows struct{}

func windowsEnv(name string) (string, error) {
	value := os.Getenv(name)
	if value == "" {
		return "", fmt.Errorf("%w: %s", ErrMissingEnv, name)
	}
	return value, nil
}

func (Windows) programFilesX86() (string, error) {
	return windowsEnv("ProgramFiles(x86)")
}

func (Windows) appData() (string, error) {
	return windowsEnv("APPDATA")
}

func (Windows) localAppData() (string, error) {
	return windowsEnv("LOCALAPPDATA")
}

// steamFactorioPath joins elems under Steam's Factorio directory.
func steamFactorioPath(root string, elems ...string) string {
	return filepath.Join(append([]string{root, "Steam", "steamapps", "common", "Factorio"}, elems...)...)
}

func (w Windows) GameExecutablePath() (string, error) {
	root, err := w.programFilesX86()
	if err != nil {
		return "", err
	}
	return steamFactorioPath(root, "bin", "x64", "factorio.exe"), nil
}

func (w Windows) GameUserDir() (string, error) {
	appData, err := w.appData()
	if err != nil {
		return "", err
	}
	return filepath.Join(appData, "Factorio"), nil
}

func (w Windows) GameDataDir() (string, error) {
	root, err := w.programFilesX86()
	if err != nil {
		return "", err
	}
	return steamFactorioPath(root, "data"), nil
}

func (w Windows) DefaultCacheHomeDir() (string, error) {
	return w.localAppData()
}

func (w Windows) DefaultConfigHomeDir() (string, error) {
	return w.appData()
}

func (w Windows) DefaultDataHomeDir() (string, error) {
	return w.localAppData()
}

func (Windows) DefaultStateHomeDir() (string, error) {
	return homePath(".local", "state")
}

func (w Windows) DefaultFactorixLogPath() (string, error) {
	stateHome, err := w.DefaultStateHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(stateHome, "factorix", "factorix.log"), nil
}

// Name identifies the platform.
func (Windows) Name() string { return "Windows" }
