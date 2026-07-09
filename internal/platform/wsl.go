package platform

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
)

// WSL locates Factorio through the Windows side of the system: it fetches
// the Windows environment variables via powershell.exe in one batch and
// converts the paths to their /mnt/<drive> equivalents. Factorix-side
// directories (cache, config, state) live in the Linux home.
type WSL struct {
	windowsEnvs func() (map[string]string, error)
}

// NewWSL returns a WSL platform. The PowerShell fetch behind windowsPath
// runs at most once, memoized via sync.OnceValues.
func NewWSL() *WSL {
	return &WSL{windowsEnvs: sync.OnceValues(fetchWindowsEnvs)}
}

// The Windows environment variables fetched in one PowerShell invocation.
const wslPowerShellScript = `[pscustomobject]@{
  "ProgramFiles(x86)" = ${Env:ProgramFiles(x86)};
  "APPDATA"           = ${Env:APPDATA};
  "LOCALAPPDATA"      = ${Env:LOCALAPPDATA}
} | ConvertTo-Json -Compress`

var wslPowerShellFallbackPaths = []string{
	"/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
	"/mnt/c/Windows/system32/WindowsPowerShell/v1.0/powershell.exe",
}

func (w *WSL) windowsPath(name string) (string, error) {
	envs, err := w.windowsEnvs()
	if err != nil {
		return "", err
	}
	value, ok := envs[name]
	if !ok || value == "" {
		return "", fmt.Errorf("%w: %s", ErrMissingEnv, name)
	}
	return convertWindowsToWSL(value)
}

func fetchWindowsEnvs() (map[string]string, error) {
	ps, err := findPowerShell()
	if err != nil {
		return nil, err
	}
	out, err := exec.Command(ps, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", wslPowerShellScript).Output()
	if err != nil {
		return nil, fmt.Errorf("PowerShell execution failed: %w", err)
	}
	var envs map[string]string
	if err := json.Unmarshal(out, &envs); err != nil {
		return nil, fmt.Errorf("cannot parse PowerShell output: %w", err)
	}
	return envs, nil
}

func findPowerShell() (string, error) {
	if path, err := exec.LookPath("powershell.exe"); err == nil {
		return path, nil
	}
	for _, path := range wslPowerShellFallbackPaths {
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}
	return "", fmt.Errorf("powershell.exe not found in PATH or default locations")
}

var windowsPathRE = regexp.MustCompile(`\A([A-Za-z]):[\\/]?(.*)\z`)

// convertWindowsToWSL maps "C:\Users\x" to "/mnt/c/Users/x".
func convertWindowsToWSL(windowsPath string) (string, error) {
	m := windowsPathRE.FindStringSubmatch(windowsPath)
	if m == nil {
		return "", fmt.Errorf("invalid Windows path: %q", windowsPath)
	}
	drive := strings.ToLower(m[1])
	rest := strings.ReplaceAll(m[2], `\`, "/")
	result := "/mnt/" + drive + "/" + rest
	// Collapse duplicate slashes and drop a trailing one.
	for strings.Contains(result, "//") {
		result = strings.ReplaceAll(result, "//", "/")
	}
	return strings.TrimSuffix(result, "/"), nil
}

func (w *WSL) GameExecutablePath() (string, error) {
	root, err := w.windowsPath("ProgramFiles(x86)")
	if err != nil {
		return "", err
	}
	return steamFactorioPath(root, "bin", "x64", "factorio.exe"), nil
}

func (w *WSL) GameUserDir() (string, error) {
	appData, err := w.windowsPath("APPDATA")
	if err != nil {
		return "", err
	}
	return filepath.Join(appData, "Factorio"), nil
}

func (w *WSL) GameDataDir() (string, error) {
	root, err := w.windowsPath("ProgramFiles(x86)")
	if err != nil {
		return "", err
	}
	return steamFactorioPath(root, "data"), nil
}

func (w *WSL) DefaultCacheHomeDir() (string, error) {
	return w.windowsPath("LOCALAPPDATA")
}

func (w *WSL) DefaultConfigHomeDir() (string, error) {
	return w.windowsPath("APPDATA")
}

func (w *WSL) DefaultDataHomeDir() (string, error) {
	return w.windowsPath("LOCALAPPDATA")
}

func (*WSL) DefaultStateHomeDir() (string, error) {
	return homePath(".local", "state")
}

func (w *WSL) DefaultFactorixLogPath() (string, error) {
	stateHome, err := w.DefaultStateHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(stateHome, "factorix", "factorix.log"), nil
}
