package platform

import "path/filepath"

// MacOS locates Factorio inside the Steam library folder that actually
// contains it, under the fixed path Steam always installs to on macOS.
// Other installations (GOG, itch.io, standalone) are covered by the
// [runtime] overrides in config.toml.
type MacOS struct{}

func (MacOS) steamRoot() (string, error) {
	return homePath("Library", "Application Support", "Steam")
}

func (m MacOS) factorioDir() (string, error) {
	root, err := m.steamRoot()
	if err != nil {
		return "", err
	}
	return findFactorioDir(root)
}

func (m MacOS) GameExecutablePath() (string, error) {
	factorioDir, err := m.factorioDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(factorioDir, "factorio.app", "Contents", "MacOS", "factorio"), nil
}

func (MacOS) GameUserDir() (string, error) {
	return homePath("Library", "Application Support", "factorio")
}

func (m MacOS) GameDataDir() (string, error) {
	factorioDir, err := m.factorioDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(factorioDir, "factorio.app", "Contents", "data"), nil
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
