package mod

import (
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"

	"golang.org/x/sync/errgroup"

	"github.com/sakuro/factorix/internal/progress"
)

const scanParallelism = 4

// ScanInstalled finds the installed MODs: ZIP files and directories in the
// MOD directory, plus the base/expansion MOD directories bundled in the
// data directory. Invalid packages are skipped with a debug log. When the
// same name and version exists in both forms, the directory wins (a
// development checkout shadows the packaged ZIP).
func ScanInstalled(modDir, dataDir string, logger *slog.Logger, listener progress.Listener) ([]InstalledMOD, error) {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}

	modPaths := collectMODPaths(modDir)
	dataPaths := collectDataPaths(dataDir)

	total := len(modPaths) + len(dataPaths)
	progress.Start(listener, int64(total))

	var (
		mu        sync.Mutex
		installed []InstalledMOD
		current   int64
	)
	step := func(im *InstalledMOD) {
		mu.Lock()
		defer mu.Unlock()
		if im != nil {
			installed = append(installed, *im)
		}
		current++
		progress.Update(listener, current)
	}

	var group errgroup.Group
	group.SetLimit(scanParallelism)
	for _, path := range modPaths {
		group.Go(func() error {
			step(scanPath(path, logger))
			return nil
		})
	}
	if err := group.Wait(); err != nil {
		return nil, err
	}

	for _, path := range dataPaths {
		step(scanPath(path, logger))
	}
	progress.Finish(listener)

	resolved := resolveDuplicates(installed)
	slices.SortStableFunc(resolved, func(a, b InstalledMOD) int {
		return b.Version.Compare(a.Version)
	})
	return resolved, nil
}

func collectMODPaths(modDir string) []string {
	entries, err := os.ReadDir(modDir)
	if err != nil {
		return nil
	}
	var paths []string
	for _, entry := range entries {
		if entry.IsDir() || strings.EqualFold(filepath.Ext(entry.Name()), ".zip") {
			paths = append(paths, filepath.Join(modDir, entry.Name()))
		}
	}
	return paths
}

// Only the base and expansion MODs live in the data directory.
func collectDataPaths(dataDir string) []string {
	entries, err := os.ReadDir(dataDir)
	if err != nil {
		return nil
	}
	var paths []string
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		candidate := MOD{Name: entry.Name()}
		if candidate.IsBase() || candidate.IsExpansion() {
			paths = append(paths, filepath.Join(dataDir, entry.Name()))
		}
	}
	return paths
}

func scanPath(path string, logger *slog.Logger) *InstalledMOD {
	info, err := os.Stat(path)
	if err != nil {
		logger.Debug("Error loading MOD package", "path", path, "error", err)
		return nil
	}

	var im InstalledMOD
	if info.IsDir() {
		im, err = InstalledMODFromDirectory(path)
	} else {
		im, err = InstalledMODFromZIP(path)
	}
	if err != nil {
		logger.Debug("Skipping invalid MOD package", "path", path, "reason", err)
		return nil
	}
	return &im
}

// resolveDuplicates keeps one package per (MOD, version), preferring the
// directory form.
func resolveDuplicates(installed []InstalledMOD) []InstalledMOD {
	type key struct {
		mod     MOD
		version MODVersion
	}
	best := map[key]InstalledMOD{}
	var order []key
	for _, im := range installed {
		k := key{mod: im.MOD, version: im.Version}
		existing, ok := best[k]
		if !ok {
			order = append(order, k)
			best[k] = im
			continue
		}
		if existing.Compare(im) < 0 {
			best[k] = im
		}
	}
	resolved := make([]InstalledMOD, 0, len(order))
	for _, k := range order {
		resolved = append(resolved, best[k])
	}
	return resolved
}
