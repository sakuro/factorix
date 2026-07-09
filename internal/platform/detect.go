package platform

import (
	"os"
	"runtime"
	"strings"
)

// procVersionPath is a variable so tests can point it at a fixture.
var procVersionPath = "/proc/version"

// Detect returns the Platform for the current OS.
func Detect() (Platform, error) {
	switch runtime.GOOS {
	case "darwin":
		return MacOS{}, nil
	case "windows":
		return Windows{}, nil
	case "linux":
		if isWSL() {
			return NewWSL(), nil
		}
		return Linux{}, nil
	default:
		return nil, &UnsupportedPlatformError{GOOS: runtime.GOOS}
	}
}

// runtime.GOOS reports "linux" on WSL; the kernel version string is the
// documented way to tell them apart.
func isWSL() bool {
	data, err := os.ReadFile(procVersionPath)
	if err != nil {
		return false
	}
	return strings.Contains(strings.ToLower(string(data)), "microsoft")
}
