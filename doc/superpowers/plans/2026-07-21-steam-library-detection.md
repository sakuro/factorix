# Steam Library-Based Factorio Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `internal/platform`'s hardcoded "Factorio lives under the default Steam library" assumption with real discovery: find the Steam install root, parse `libraryfolders.vdf` to find which library folder actually contains Factorio (AppID `427520`), and derive `GameExecutablePath()`/`GameDataDir()` from that.

**Architecture:** A new shared helper `findFactorioDir(steamRoot string) (string, error)` in `internal/platform/steam.go` parses `libraryfolders.vdf` with a minimal line-scanning parser (no VDF dependency). Each OS's `Platform` implementation gains a `steamRoot() (string, error)` method (filesystem checks on Linux/macOS, PowerShell + registry on Windows/WSL) and calls `findFactorioDir` from `GameExecutablePath`/`GameDataDir`. `Windows` changes from a value type to a pointer type (`NewWindows()`) so its registry read can be memoized like `WSL` already memoizes its PowerShell fetch.

**Tech Stack:** Go 1.26, testify (`assert`/`require`), no new dependencies.

**Reference:** Design spec at `docs/superpowers/specs/2026-07-21-steam-library-detection-design.md`.

---

### Task 1: Create the feature branch

**Files:** none

- [ ] **Step 1: Create and switch to the feature branch**

Run: `git checkout -b feature/steam-library-detection`
Expected: `Switched to a new branch 'feature/steam-library-detection'`

---

### Task 2: `libraryfolders.vdf` parser (`steam.go`)

**Files:**
- Create: `internal/platform/steam.go`
- Create: `internal/platform/steam_test.go`

- [ ] **Step 1: Write the failing tests**

Create `internal/platform/steam_test.go`:

```go
package platform

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// factorioLibraryVDF returns libraryfolders.vdf content for a single
// library at libraryPath that contains Factorio.
func factorioLibraryVDF(libraryPath string) string {
	return `"libraryfolders"
{
	"0"
	{
		"path"		"` + libraryPath + `"
		"apps"
		{
			"427520"		"654321000"
		}
	}
}
`
}

// writeLibraryFolders writes content to <steamRoot>/steamapps/libraryfolders.vdf.
func writeLibraryFolders(t *testing.T, steamRoot, content string) {
	t.Helper()
	dir := filepath.Join(steamRoot, "steamapps")
	require.NoError(t, os.MkdirAll(dir, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "libraryfolders.vdf"), []byte(content), 0o644))
}

func TestFindFactorioDirSingleLibrary(t *testing.T) {
	root := t.TempDir()
	writeLibraryFolders(t, root, factorioLibraryVDF(root))

	dir, err := findFactorioDir(root)
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(root, "steamapps", "common", "Factorio"), dir)
}

func TestFindFactorioDirNonDefaultLibrary(t *testing.T) {
	root := t.TempDir()
	otherLibrary := filepath.Join(t.TempDir(), "SteamLibrary")
	writeLibraryFolders(t, root, `"libraryfolders"
{
	"0"
	{
		"path"		"`+root+`"
		"apps"
		{
			"228980"		"476349747"
		}
	}
	"1"
	{
		"path"		"`+otherLibrary+`"
		"apps"
		{
			"427520"		"654321000"
		}
	}
}
`)

	dir, err := findFactorioDir(root)
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(otherLibrary, "steamapps", "common", "Factorio"), dir)
}

func TestFindFactorioDirNotFound(t *testing.T) {
	root := t.TempDir()
	writeLibraryFolders(t, root, `"libraryfolders"
{
	"0"
	{
		"path"		"`+root+`"
		"apps"
		{
			"228980"		"476349747"
		}
	}
}
`)

	_, err := findFactorioDir(root)
	require.ErrorIs(t, err, ErrFactorioNotFound)
}

func TestFindFactorioDirMissingFile(t *testing.T) {
	root := t.TempDir()

	_, err := findFactorioDir(root)
	require.Error(t, err)
}

func TestFindFactorioDirEscapedBackslashes(t *testing.T) {
	root := t.TempDir()
	writeLibraryFolders(t, root, `"libraryfolders"
{
	"0"
	{
		"path"		"C:\\Program Files (x86)\\Steam"
		"apps"
		{
			"427520"		"654321000"
		}
	}
}
`)

	dir, err := findFactorioDir(root)
	require.NoError(t, err)
	assert.Equal(t, filepath.Join(`C:\Program Files (x86)\Steam`, "steamapps", "common", "Factorio"), dir)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/platform/... -run TestFindFactorioDir -v`
Expected: FAIL to compile with `undefined: findFactorioDir` and `undefined: ErrFactorioNotFound`

- [ ] **Step 3: Implement `findFactorioDir`**

Create `internal/platform/steam.go`:

```go
package platform

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// factorioAppID is Factorio's Steam application ID, used to identify which
// Steam library folder (if any) contains the game.
const factorioAppID = "427520"

// ErrFactorioNotFound reports that no Steam library folder contains Factorio.
var ErrFactorioNotFound = errors.New("Factorio installation not found in any Steam library")

var vdfKeyValueRE = regexp.MustCompile(`^\s*"([^"]*)"\s*"([^"]*)"\s*$`)

// findFactorioDir parses steamRoot/steamapps/libraryfolders.vdf, which
// lists every Steam library folder (including the default one under
// steamRoot) together with the AppIDs installed in each, and returns the
// Factorio installation directory in whichever library actually holds it.
//
// The parser only tracks the two things it needs - the most recent "path"
// value and whether factorioAppID appears in the "apps" block that
// follows it - relying on Valve's libraryfolders.vdf always emitting
// "path" before "apps" within a library block.
func findFactorioDir(steamRoot string) (string, error) {
	vdfPath := filepath.Join(steamRoot, "steamapps", "libraryfolders.vdf")
	f, err := os.Open(vdfPath)
	if err != nil {
		return "", err
	}
	defer f.Close()

	var currentPath string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		m := vdfKeyValueRE.FindStringSubmatch(scanner.Text())
		if m == nil {
			continue
		}
		key, value := m[1], m[2]
		switch key {
		case "path":
			currentPath = unescapeVDFString(value)
		case factorioAppID:
			if currentPath == "" {
				continue
			}
			return filepath.Join(currentPath, "steamapps", "common", "Factorio"), nil
		}
	}
	if err := scanner.Err(); err != nil {
		return "", fmt.Errorf("cannot read %s: %w", vdfPath, err)
	}
	return "", fmt.Errorf("%w: %s", ErrFactorioNotFound, vdfPath)
}

// unescapeVDFString undoes Valve's backslash-escaping of path separators
// (e.g. `C:\\Program Files (x86)\\Steam` -> `C:\Program Files (x86)\Steam`).
func unescapeVDFString(s string) string {
	return strings.ReplaceAll(s, `\\`, `\`)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `go test ./internal/platform/... -run TestFindFactorioDir -v`
Expected: PASS (all 5 subtests)

- [ ] **Step 5: Commit**

```bash
git add internal/platform/steam.go internal/platform/steam_test.go
git commit -m ":sparkles: Add libraryfolders.vdf parser for Steam library discovery"
```

---

### Task 3: Linux - discover Steam root instead of hardcoding it

**Files:**
- Modify: `internal/platform/linux.go`
- Modify: `internal/platform/platform_test.go:29-44` (`TestLinuxPaths`), and `:122-141` (`TestRuntimeOverrides`)

- [ ] **Step 1: Write the failing tests**

Replace `TestLinuxPaths` in `internal/platform/platform_test.go` (currently lines 29-44):

```go
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
```

Also update `TestRuntimeOverrides` (currently lines 122-141) to give `Linux{}.GameDataDir()` a real Steam fixture to find, since it now touches the filesystem:

```go
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/platform/... -run 'TestLinuxPaths|TestLinuxSteamRoot|TestRuntimeOverrides' -v`
Expected: FAIL - `TestLinuxPaths` and `TestRuntimeOverrides` produce wrong paths (still hardcoded); `TestLinuxSteamRoot*` fail to compile (`steamRoot` undefined on `Linux`)

- [ ] **Step 3: Implement Steam root discovery in `linux.go`**

Replace the full contents of `internal/platform/linux.go`:

```go
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

func (l Linux) GameExecutablePath() (string, error) {
	root, err := l.steamRoot()
	if err != nil {
		return "", err
	}
	factorioDir, err := findFactorioDir(root)
	if err != nil {
		return "", err
	}
	return filepath.Join(factorioDir, "bin", "x64", "factorio"), nil
}

func (Linux) GameUserDir() (string, error) {
	return homePath(".factorio")
}

func (l Linux) GameDataDir() (string, error) {
	root, err := l.steamRoot()
	if err != nil {
		return "", err
	}
	factorioDir, err := findFactorioDir(root)
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `go test ./internal/platform/... -run 'TestLinuxPaths|TestLinuxSteamRoot|TestRuntimeOverrides' -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/platform/linux.go internal/platform/platform_test.go
git commit -m ":sparkles: Discover Factorio via Steam library folders on Linux"
```

---

### Task 4: macOS - locate Factorio via Steam library discovery

**Files:**
- Modify: `internal/platform/macos.go`
- Modify: `internal/platform/platform_test.go:46-57` (`TestMacOSPaths`)

- [ ] **Step 1: Write the failing test**

Replace `TestMacOSPaths` in `internal/platform/platform_test.go` (currently lines 46-57):

```go
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/platform/... -run TestMacOSPaths -v`
Expected: FAIL - `GameExecutablePath`/`GameDataDir` still return the old hardcoded paths

- [ ] **Step 3: Implement Steam root discovery in `macos.go`**

Replace the full contents of `internal/platform/macos.go`:

```go
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

func (m MacOS) GameExecutablePath() (string, error) {
	root, err := m.steamRoot()
	if err != nil {
		return "", err
	}
	factorioDir, err := findFactorioDir(root)
	if err != nil {
		return "", err
	}
	return filepath.Join(factorioDir, "factorio.app", "Contents", "MacOS", "factorio"), nil
}

func (MacOS) GameUserDir() (string, error) {
	return homePath("Library", "Application Support", "factorio")
}

func (m MacOS) GameDataDir() (string, error) {
	root, err := m.steamRoot()
	if err != nil {
		return "", err
	}
	factorioDir, err := findFactorioDir(root)
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/platform/... -run TestMacOSPaths -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/platform/macos.go internal/platform/platform_test.go
git commit -m ":sparkles: Discover Factorio via Steam library folders on macOS"
```

---

### Task 5: Windows - read the Steam registry key via PowerShell

**Files:**
- Modify: `internal/platform/windows.go`
- Modify: `internal/platform/detect.go:18`
- Modify: `internal/platform/platform_test.go:59-78` (`TestWindowsPaths`, `TestWindowsPathsMissingEnv`)

- [ ] **Step 1: Write the failing tests**

Replace `TestWindowsPaths` and `TestWindowsPathsMissingEnv` in `internal/platform/platform_test.go` (currently lines 59-78):

```go
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/platform/... -run TestWindows -v`
Expected: FAIL to compile - `NewWindows` undefined, `w.steamPath` undefined (Windows is still a zero-field value type)

- [ ] **Step 3: Convert `Windows` to a pointer type with a memoized registry read**

Replace the full contents of `internal/platform/windows.go`:

```go
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
	steamPath func() (string, error)
}

// NewWindows returns a Windows platform. The registry read behind
// steamPath runs at most once, memoized via sync.OnceValues.
func NewWindows() *Windows {
	return &Windows{steamPath: sync.OnceValues(fetchWindowsSteamPath)}
}

const windowsSteamPathScript = `(Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath).SteamPath`

func fetchWindowsSteamPath() (string, error) {
	out, err := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", windowsSteamPathScript).Output()
	if err != nil {
		return "", fmt.Errorf("PowerShell execution failed: %w", err)
	}
	path := strings.TrimSpace(string(out))
	if path == "" {
		return "", fmt.Errorf("%w: Steam registry key", ErrMissingEnv)
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

func (w *Windows) GameExecutablePath() (string, error) {
	root, err := w.steamPath()
	if err != nil {
		return "", err
	}
	factorioDir, err := findFactorioDir(root)
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
	root, err := w.steamPath()
	if err != nil {
		return "", err
	}
	factorioDir, err := findFactorioDir(root)
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
```

- [ ] **Step 4: Update `detect.go` to construct `*Windows` via `NewWindows()`**

In `internal/platform/detect.go`, change line 18:

```go
	case "windows":
		return NewWindows(), nil
```

(was `return Windows{}, nil`)

- [ ] **Step 5: Run tests to verify they pass**

Run: `go test ./internal/platform/... -run 'TestWindows|TestDetect' -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add internal/platform/windows.go internal/platform/detect.go internal/platform/platform_test.go
git commit -m ":sparkles: Discover Factorio via the Steam registry key on Windows"
```

---

### Task 6: WSL - fetch the Steam registry key in the existing PowerShell batch call

**Files:**
- Modify: `internal/platform/wsl.go`
- Modify: `internal/platform/platform_test.go` (add `TestWSLSteamRoot` near `TestConvertWindowsToWSL`)

- [ ] **Step 1: Write the failing test**

Add to `internal/platform/platform_test.go`, near `TestConvertWindowsToWSL` (currently ending at line 95):

```go
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/platform/... -run TestWSLSteamRoot -v`
Expected: FAIL to compile - `steamRoot` undefined on `*WSL`

- [ ] **Step 3: Add `SteamPath` to the batch fetch and implement `steamRoot`**

In `internal/platform/wsl.go`, replace the `wslPowerShellScript` constant (currently lines 29-33):

```go
// The Windows environment variables and Steam registry key fetched in one
// PowerShell invocation.
const wslPowerShellScript = `[pscustomobject]@{
  "APPDATA"      = ${Env:APPDATA};
  "LOCALAPPDATA" = ${Env:LOCALAPPDATA};
  "SteamPath"    = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
} | ConvertTo-Json -Compress`
```

(this drops the now-unused `ProgramFiles(x86)` entry, replacing it with `SteamPath`)

Add a `steamRoot` method right after `windowsPath` (currently ending at line 50):

```go
func (w *WSL) steamRoot() (string, error) {
	return w.windowsPath("SteamPath")
}
```

Replace `GameExecutablePath` and `GameDataDir` (currently lines 98-104 and 114-120):

```go
func (w *WSL) GameExecutablePath() (string, error) {
	root, err := w.steamRoot()
	if err != nil {
		return "", err
	}
	factorioDir, err := findFactorioDir(root)
	if err != nil {
		return "", err
	}
	return filepath.Join(factorioDir, "bin", "x64", "factorio.exe"), nil
}
```

```go
func (w *WSL) GameDataDir() (string, error) {
	root, err := w.steamRoot()
	if err != nil {
		return "", err
	}
	factorioDir, err := findFactorioDir(root)
	if err != nil {
		return "", err
	}
	return filepath.Join(factorioDir, "data"), nil
}
```

- [ ] **Step 4: Remove the now-dead `steamFactorioPath` helper**

`steamFactorioPath` (previously defined in `windows.go`, already removed in Task 5 Step 3) was the only place `wsl.go` depended on cross-file. Confirm no remaining references:

Run: `grep -rn steamFactorioPath internal/platform/`
Expected: no output

- [ ] **Step 5: Run tests to verify they pass**

Run: `go test ./internal/platform/... -run 'TestWSL|TestConvertWindowsToWSL|TestIsWSL' -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add internal/platform/wsl.go internal/platform/platform_test.go
git commit -m ":sparkles: Discover Factorio via the Steam registry key on WSL"
```

---

### Task 7: Full verification and CHANGELOG entry

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add a CHANGELOG entry**

In `CHANGELOG.md`, under `## [Unreleased]`, add a `### Changed` section above the existing `### Fixed` section (or add to an existing `### Changed` section if one already exists by the time this runs):

```markdown
### Changed

- Detect Factorio's actual Steam library location by parsing `libraryfolders.vdf` instead of assuming the default Steam library, so `data_dir`/`executable_path` auto-detection also finds installations in a non-default Steam library folder on Linux, macOS, Windows, and WSL
```

- [ ] **Step 2: Run the full test suite**

Run: `go test ./...`
Expected: all packages PASS

- [ ] **Step 3: Run go vet**

Run: `go vet ./...`
Expected: no output

- [ ] **Step 4: Run golangci-lint**

Run: `golangci-lint run ./...`
Expected: no issues

- [ ] **Step 5: Run gofmt check**

Run: `test -z "$(gofmt -l .)"`
Expected: no output (empty diff)

- [ ] **Step 6: Run e2e tests**

Run: `go test -count=1 ./e2e/`
Expected: all PASS (confirms `mod list`/`mod show`/`mod search` and other commands that build a `Runtime` still work end to end)

- [ ] **Step 7: Fix any failures found in Steps 2-6 before proceeding**

If any command fails, fix the root cause (not by weakening a check) and re-run the failing command until it passes.

- [ ] **Step 8: Commit the CHANGELOG entry**

```bash
git add CHANGELOG.md
git commit -m ":memo: Note Steam library-based Factorio detection in CHANGELOG"
```

---

### Task 8: Open the pull request

**Files:** none

- [ ] **Step 1: Push the branch**

Run: `git push -u origin feature/steam-library-detection`

- [ ] **Step 2: Open the PR**

```bash
gh pr create --title ":sparkles: Discover Factorio via Steam library folders instead of assuming the default library" --body "$(cat <<'EOF'
## Summary
- internal/platform previously hardcoded Factorio's path under each OS's *default* Steam library. This breaks when Factorio is installed in a non-default Steam library folder (a common Steam feature).
- Add a shared `findFactorioDir` (internal/platform/steam.go) that parses `steamapps/libraryfolders.vdf` to find which library actually contains Factorio (Steam AppID 427520).
- Each OS's Platform implementation now discovers its Steam root (filesystem checks on Linux/macOS, the Steam registry key read via PowerShell on Windows/WSL) and derives GameExecutablePath/GameDataDir from the discovered library.
- Windows changes from a value type to a pointer type (NewWindows()) so its registry read is memoized, mirroring WSL's existing PowerShell memoization.

## Test plan
- [x] `go test ./...`
- [x] `go vet ./...`
- [x] `golangci-lint run ./...`
- [x] `gofmt -l .` (empty)
- [x] `go test -count=1 ./e2e/`

See docs/superpowers/specs/2026-07-21-steam-library-detection-design.md for the full design.
EOF
)"
```

- [ ] **Step 3: Report the PR URL to the user**

`gh pr create` prints the PR URL on success - relay it back.
