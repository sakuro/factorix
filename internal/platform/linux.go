package platform

import "path/filepath"

// Linux assumes a Steam installation; other installations (standalone,
// Flatpak, Snap) are covered by the [runtime] overrides in config.toml.
type Linux struct{}

func (Linux) GameExecutablePath() (string, error) {
	return homePath(".steam", "steam", "steamapps", "common", "Factorio", "bin", "x64", "factorio")
}

func (Linux) GameUserDir() (string, error) {
	return homePath(".factorio")
}

func (Linux) GameDataDir() (string, error) {
	return homePath(".steam", "steam", "steamapps", "common", "Factorio", "data")
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
