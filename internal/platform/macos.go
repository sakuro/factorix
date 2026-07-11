package platform

import "path/filepath"

// MacOS assumes a Steam installation; other installations (GOG, itch.io,
// standalone) are covered by the [runtime] overrides in config.toml.
type MacOS struct{}

func (MacOS) GameExecutablePath() (string, error) {
	return homePath("Library", "Application Support", "Steam", "steamapps", "common", "Factorio",
		"factorio.app", "Contents", "MacOS", "factorio")
}

func (MacOS) GameUserDir() (string, error) {
	return homePath("Library", "Application Support", "factorio")
}

func (MacOS) GameDataDir() (string, error) {
	return homePath("Library", "Application Support", "Steam", "steamapps", "common", "Factorio",
		"factorio.app", "Contents", "data")
}

func (MacOS) DefaultCacheHomeDir() (string, error) {
	return homePath("Library", "Caches")
}

func (MacOS) DefaultConfigHomeDir() (string, error) {
	return homePath("Library", "Application Support")
}

func (MacOS) DefaultDataHomeDir() (string, error) {
	return homePath("Library", "Application Support")
}

func (MacOS) DefaultStateHomeDir() (string, error) {
	return homePath(".local", "state")
}

// DefaultFactorixLogPath follows the macOS convention (~/Library/Logs), not
// the XDG state directory.
func (MacOS) DefaultFactorixLogPath() (string, error) {
	dir, err := homePath("Library", "Logs")
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "factorix", "factorix.log"), nil
}

// Name identifies the platform.
func (MacOS) Name() string { return "MacOS" }
