package cli

import (
	"context"
	"errors"
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"slices"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

var builtinMODs = []string{"base", "elevated-rails", "quality", "space-age"}

func newMODDownloadCommand(c *cli) *cobra.Command {
	var directory string
	var jobs int
	var recursive bool

	cmd := &cobra.Command{
		Use:   "download <mod-spec>...",
		Short: "Download MOD files from Factorio MOD Portal",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}

			downloadDir, err := filepath.Abs(directory)
			if err != nil {
				return err
			}
			if info, err := os.Stat(downloadDir); err != nil || !info.IsDir() {
				return fmt.Errorf("Download directory does not exist: %s", downloadDir)
			}
			sameDir, err := sameDirAsMODDir(application, downloadDir)
			if err != nil {
				return err
			}
			if sameDir {
				return fmt.Errorf("Cannot download to MOD directory. Use 'mod install' instead.")
			}

			specs := make([]modSpec, len(args))
			for i, arg := range args {
				spec, err := parseMODSpec(arg)
				if err != nil {
					return err
				}
				specs[i] = spec
			}

			targets, err := planDownload(cmd.Context(), application, specs, downloadDir, jobs, recursive)
			if err != nil {
				return err
			}

			p := c.printer(cmd)
			if len(targets) == 0 {
				p.Info("No MOD(s) to download")
				return nil
			}

			if err := downloadTargets(cmd.Context(), application, targets, jobs); err != nil {
				return err
			}
			p.Success(fmt.Sprintf("Downloaded %d MOD(s)", len(targets)))
			return nil
		},
	}
	cmd.Flags().StringVarP(&directory, "directory", "d", ".", "Download directory")
	cmd.Flags().IntVarP(&jobs, "jobs", "j", 4, "Number of parallel downloads")
	cmd.Flags().BoolVarP(&recursive, "recursive", "r", false, "Include required dependencies recursively")
	return cmd
}

// sameDirAsMODDir reports whether dir and the MOD directory are the same
// path, resolving symlinks. A nonexistent MOD directory can't be equal to
// anything, so it short-circuits rather than erroring on EvalSymlinks.
func sameDirAsMODDir(application *app.App, dir string) (bool, error) {
	modDir, err := application.Runtime.MODDir()
	if err != nil {
		return false, err
	}
	if _, err := os.Stat(modDir); err != nil {
		return false, nil
	}
	realDownloadDir, err := filepath.EvalSymlinks(dir)
	if err != nil {
		return false, err
	}
	realMODDir, err := filepath.EvalSymlinks(modDir)
	if err != nil {
		return false, err
	}
	return realDownloadDir == realMODDir, nil
}

func planDownload(ctx context.Context, application *app.App, specs []modSpec, downloadDir string, jobs int, recursive bool) ([]downloadTarget, error) {
	portalAPI, err := application.PortalAPI()
	if err != nil {
		return nil, err
	}

	initial, err := fetchMODInfoConcurrently(ctx, jobs, specs, func(ctx context.Context, spec modSpec) (fetchedMODInfo, error) {
		info, err := portalAPI.GetMOD(ctx, spec.MOD.Name)
		if err != nil {
			return fetchedMODInfo{}, err
		}
		release := findRelease(info, spec)
		if release == nil {
			return fetchedMODInfo{}, fmt.Errorf("Release not found for %s@%s", spec.MOD.Name, specVersionLabel(spec))
		}
		return fetchedMODInfo{MOD: spec.MOD, MODInfo: info, Release: *release}, nil
	})
	if err != nil {
		return nil, err
	}

	all := initial
	if recursive {
		all, err = resolveDownloadDependencies(ctx, application, initial, jobs)
		if err != nil {
			return nil, err
		}
	}
	return buildDownloadTargets(all, downloadDir)
}

func specVersionLabel(spec modSpec) string {
	if spec.Latest {
		return "latest"
	}
	return spec.Version.String()
}

type requiredDependency struct {
	name        string
	requirement *dependency.VersionRequirement
}

// resolveDownloadDependencies expands the initial fetch set with required
// dependencies (recursively), skipping builtin MODs. A dependency with no
// compatible release, or that errors while fetching, is skipped with a
// warning rather than failing the whole download — a single incompatible
// dependency should not block installing the MODs the user actually asked
// for.
func resolveDownloadDependencies(ctx context.Context, application *app.App, initial []fetchedMODInfo, jobs int) ([]fetchedMODInfo, error) {
	portalAPI, err := application.PortalAPI()
	if err != nil {
		return nil, err
	}

	known := map[string]fetchedMODInfo{}
	frontier := make([]string, 0, len(initial))
	for _, info := range initial {
		known[info.MOD.Name] = info
		frontier = append(frontier, info.MOD.Name)
	}
	processed := map[string]bool{}

	for len(frontier) > 0 {
		newDeps := collectNewDependencies(frontier, known, processed)
		frontier = nil
		if len(newDeps) == 0 {
			continue
		}

		specs := make([]modSpec, len(newDeps))
		for i, dep := range newDeps {
			specs[i] = modSpec{MOD: mod.MOD{Name: dep.name}}
		}
		results, err := fetchMODInfoConcurrently(ctx, jobs, specs, func(ctx context.Context, spec modSpec) (fetchedMODInfo, error) {
			info, err := portalAPI.GetMOD(ctx, spec.MOD.Name)
			if err != nil {
				return fetchedMODInfo{}, warnAndSkip(application, spec.MOD.Name, err)
			}
			i := slices.IndexFunc(newDeps, func(d requiredDependency) bool { return d.name == spec.MOD.Name })
			release := findCompatibleRelease(info, newDeps[i].requirement)
			if release == nil {
				return fetchedMODInfo{}, warnAndSkip(application, spec.MOD.Name, errors.New("no compatible release found"))
			}
			return fetchedMODInfo{MOD: spec.MOD, MODInfo: info, Release: *release}, nil
		})
		if err != nil {
			return nil, err
		}

		for _, r := range results {
			if r.MODInfo == nil {
				continue // skipped: warnAndSkip already logged the reason
			}
			known[r.MOD.Name] = r
			frontier = append(frontier, r.MOD.Name)
		}
	}

	return slices.Collect(maps.Values(known)), nil
}

// warnAndSkip logs and returns nil so the caller treats the dependency as
// skippable rather than fatal.
func warnAndSkip(application *app.App, modName string, cause error) error {
	application.Logger.Warn("Skipping dependency", "mod", modName, "reason", cause)
	return nil
}

func collectNewDependencies(batch []string, known map[string]fetchedMODInfo, processed map[string]bool) []requiredDependency {
	var newDeps []requiredDependency
	for _, name := range batch {
		if processed[name] {
			continue
		}
		processed[name] = true

		info, ok := known[name]
		if !ok {
			continue
		}
		for _, depString := range info.Release.InfoJSON.Dependencies {
			entry, err := dependency.Parse(depString)
			if err != nil || entry.Type != dependency.TypeRequired {
				continue
			}
			if slices.Contains(builtinMODs, entry.MOD.Name) {
				continue
			}
			if _, ok := known[entry.MOD.Name]; ok {
				continue
			}
			newDeps = append(newDeps, requiredDependency{name: entry.MOD.Name, requirement: entry.Requirement})
		}
	}
	return newDeps
}
