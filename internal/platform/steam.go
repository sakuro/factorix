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
