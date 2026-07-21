package platform

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// setHome points the home directory at a temp dir for the test.
// os.UserHomeDir reads $HOME on Unix; these tests do not run on Windows CI.
func setHome(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	return home
}

func clearXDG(t *testing.T) {
	t.Helper()
	for _, v := range []string{"XDG_CACHE_HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME"} {
		t.Setenv(v, "") // ensure restoration...
		os.Unsetenv(v)
	}
}

func TestLinuxPaths(t *testing.T) {
	home := setHome(t)
	steamRoot := filepath.Join(home, ".steam", "steam")
	writeLibraryFolders(t, steamRoot, factorioLibraryVDF(steamRoot))
	p := Linux{}

	exe, err := p.GameExecutablePath()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(steamRoot, "steamapps", "common", "Factorio", "bin", "x64", "factorio"), exe)

	userDir, err := p.GameUserDir()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, ".factorio"), userDir)

	dataDir, err := p.GameDataDir()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(steamRoot, "steamapps", "common", "Factorio", "data"), dataDir)
}

func TestLinuxSteamRootFlatpakFallback(t *testing.T) {
	home := setHome(t)
	flatpakRoot := filepath.Join(home, ".var", "app", "com.valvesoftware.Steam", ".steam", "steam")
	writeLibraryFolders(t, flatpakRoot, factorioLibraryVDF(flatpakRoot))

	root, err := Linux{}.steamRoot()
	require.NoError(t, err)
	assert.Equal(t, flatpakRoot, root)
}

func TestLinuxSteamRootNativeTakesPrecedence(t *testing.T) {
	home := setHome(t)
	nativeRoot := filepath.Join(home, ".steam", "steam")
	flatpakRoot := filepath.Join(home, ".var", "app", "com.valvesoftware.Steam", ".steam", "steam")
	writeLibraryFolders(t, nativeRoot, factorioLibraryVDF(nativeRoot))
	writeLibraryFolders(t, flatpakRoot, factorioLibraryVDF(flatpakRoot))

	root, err := Linux{}.steamRoot()
	require.NoError(t, err)
	assert.Equal(t, nativeRoot, root)
}

func TestLinuxSteamRootNotFound(t *testing.T) {
	setHome(t)

	_, err := Linux{}.steamRoot()
	require.Error(t, err)
}

func TestMacOSPaths(t *testing.T) {
	home := setHome(t)
	steamRoot := filepath.Join(home, "Library", "Application Support", "Steam")
	writeLibraryFolders(t, steamRoot, factorioLibraryVDF(steamRoot))
	p := MacOS{}

	userDir, err := p.GameUserDir()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, "Library/Application Support/factorio"), userDir)

	exe, err := p.GameExecutablePath()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(steamRoot, "steamapps", "common", "Factorio", "factorio.app", "Contents", "MacOS", "factorio"), exe)

	dataDir, err := p.GameDataDir()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(steamRoot, "steamapps", "common", "Factorio", "factorio.app", "Contents", "data"), dataDir)

	logPath, err := p.DefaultFactorixLogPath()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, "Library/Logs/factorix/factorix.log"), logPath)
}

func TestWindowsPaths(t *testing.T) {
	t.Setenv("APPDATA", `C:\Users\test\AppData\Roaming`)
	t.Setenv("LOCALAPPDATA", `C:\Users\test\AppData\Local`)
	steamRoot := t.TempDir()
	writeLibraryFolders(t, steamRoot, factorioLibraryVDF(steamRoot))
	w := NewWindows()
	w.steamPath = func() (string, error) { return steamRoot, nil }

	exe, err := w.GameExecutablePath()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(steamRoot, "steamapps", "common", "Factorio", "bin", "x64", "factorio.exe"), exe)

	userDir, err := w.GameUserDir()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(`C:\Users\test\AppData\Roaming`, "Factorio"), userDir)

	dataDir, err := w.GameDataDir()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(steamRoot, "steamapps", "common", "Factorio", "data"), dataDir)
}

func TestWindowsPathsMissingEnv(t *testing.T) {
	t.Setenv("APPDATA", "")
	_, err := NewWindows().GameUserDir()
	require.ErrorIs(t, err, ErrMissingEnv)
}

func TestWindowsSteamPathError(t *testing.T) {
	w := NewWindows()
	w.steamPath = func() (string, error) { return "", ErrMissingEnv }

	_, err := w.GameExecutablePath()
	require.ErrorIs(t, err, ErrMissingEnv)
}

func TestConvertWindowsToWSL(t *testing.T) {
	tests := map[string]string{
		`C:\Program Files (x86)`:        "/mnt/c/Program Files (x86)",
		`C:\Users\test\AppData\Roaming`: "/mnt/c/Users/test/AppData/Roaming",
		`D:/Games/Factorio`:             "/mnt/d/Games/Factorio",
		`C:\`:                           "/mnt/c",
	}
	for input, want := range tests {
		got, err := convertWindowsToWSL(input)
		require.NoError(t, err)
		assert.Equal(t, want, got, input)
	}

	_, err := convertWindowsToWSL("not a windows path")
	require.Error(t, err)
}

func TestWSLSteamRoot(t *testing.T) {
	w := &WSL{windowsEnvs: func() (map[string]string, error) {
		return map[string]string{
			"APPDATA":      `C:\Users\test\AppData\Roaming`,
			"LOCALAPPDATA": `C:\Users\test\AppData\Local`,
			"SteamPath":    `D:\SteamLibrary`,
		}, nil
	}}

	root, err := w.steamRoot()
	require.NoError(t, err)
	assert.Equal(t, "/mnt/d/SteamLibrary", root)
}

func TestWSLSteamRootMissing(t *testing.T) {
	w := &WSL{windowsEnvs: func() (map[string]string, error) {
		return map[string]string{
			"APPDATA":      `C:\Users\test\AppData\Roaming`,
			"LOCALAPPDATA": `C:\Users\test\AppData\Local`,
		}, nil
	}}

	_, err := w.steamRoot()
	require.ErrorIs(t, err, ErrMissingEnv)
}

func TestRuntimeDerivedPaths(t *testing.T) {
	home := setHome(t)
	r := NewRuntime(Linux{}, Overrides{})

	modDir, err := r.MODDir()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, ".factorio/mods"), modDir)

	modListPath, err := r.MODListPath()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, ".factorio/mods/mod-list.json"), modListPath)

	settingsPath, err := r.MODSettingsPath()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, ".factorio/mods/mod-settings.dat"), settingsPath)

	saveDir, err := r.SaveDir()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, ".factorio/saves"), saveDir)

	playerData, err := r.PlayerDataPath()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, ".factorio/player-data.json"), playerData)
}

func TestRuntimeOverrides(t *testing.T) {
	home := setHome(t)
	steamRoot := filepath.Join(home, ".steam", "steam")
	writeLibraryFolders(t, steamRoot, factorioLibraryVDF(steamRoot))
	r := NewRuntime(Linux{}, Overrides{
		ExecutablePath: "/opt/factorio/bin/x64/factorio",
		UserDir:        "/srv/factorio",
	})

	exe, err := r.ExecutablePath()
	require.NoError(t, err)
	assert.Equal(t, "/opt/factorio/bin/x64/factorio", exe)

	modDir, err := r.MODDir()
	require.NoError(t, err)
	assert.Equal(t, "/srv/factorio/mods", modDir)

	// DataDir has no override and falls back to auto-detection.
	dataDir, err := r.DataDir()
	require.NoError(t, err)
	assert.Contains(t, dataDir, ".steam")
}

func TestRuntimeXDGDirs(t *testing.T) {
	home := setHome(t)
	clearXDG(t)
	r := NewRuntime(Linux{}, Overrides{})

	cacheDir, err := r.FactorixCacheDir()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, ".cache/factorix"), cacheDir)

	configPath, err := r.FactorixConfigPath()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, ".config/factorix/config.toml"), configPath)

	logPath, err := r.FactorixLogPath()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, ".local/state/factorix/factorix.log"), logPath)

	t.Setenv("XDG_CACHE_HOME", "/custom/cache")
	t.Setenv("XDG_STATE_HOME", "/custom/state")

	cacheDir, err = r.FactorixCacheDir()
	require.NoError(t, err)
	assert.Equal(t, "/custom/cache/factorix", cacheDir)

	logPath, err = r.FactorixLogPath()
	require.NoError(t, err)
	assert.Equal(t, "/custom/state/factorix/factorix.log", logPath)
}

func TestMacOSLogPathHonorsXDGStateHome(t *testing.T) {
	home := setHome(t)
	clearXDG(t)
	r := NewRuntime(MacOS{}, Overrides{})

	logPath, err := r.FactorixLogPath()
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(home, "Library/Logs/factorix/factorix.log"), logPath)

	t.Setenv("XDG_STATE_HOME", "/sandbox/state")
	logPath, err = r.FactorixLogPath()
	require.NoError(t, err)
	assert.Equal(t, "/sandbox/state/factorix/factorix.log", logPath)
}

func TestRuntimeIsRunning(t *testing.T) {
	userDir := t.TempDir()
	r := NewRuntime(Linux{}, Overrides{UserDir: userDir})

	running, err := r.IsRunning()
	require.NoError(t, err)
	assert.False(t, running)

	require.NoError(t, os.WriteFile(filepath.Join(userDir, ".lock"), nil, 0o644))
	running, err = r.IsRunning()
	require.NoError(t, err)
	assert.True(t, running)
}

func TestIsWSL(t *testing.T) {
	dir := t.TempDir()
	fake := filepath.Join(dir, "version")

	orig := procVersionPath
	defer func() { procVersionPath = orig }()
	procVersionPath = fake

	assert.False(t, isWSL()) // file absent

	require.NoError(t, os.WriteFile(fake, []byte("Linux version 6.6.0 (Microsoft@Microsoft.com)"), 0o644))
	assert.True(t, isWSL())

	require.NoError(t, os.WriteFile(fake, []byte("Linux version 6.6.0 (gcc ...)"), 0o644))
	assert.False(t, isWSL())
}

func TestDetect(t *testing.T) {
	p, err := Detect()
	require.NoError(t, err)
	assert.NotNil(t, p)
}
