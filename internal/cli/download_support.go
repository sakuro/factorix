package cli

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"strings"

	"golang.org/x/sync/errgroup"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/progress"
	"github.com/sakuro/factorix/internal/transfer"
)

var errInvalidFilename = errors.New("invalid filename")

// modSpec is a parsed "name", "name@version", or "name@latest" argument.
type modSpec struct {
	MOD     mod.MOD
	Latest  bool
	Version mod.MODVersion // meaningless when Latest
}

// parseMODSpec parses a MOD specification. "latest" and the bare name both
// mean the latest release.
func parseMODSpec(spec string) (modSpec, error) {
	name, versionStr, hasVersion := strings.Cut(spec, "@")
	if !hasVersion || versionStr == "" || versionStr == "latest" {
		return modSpec{MOD: mod.MOD{Name: name}, Latest: true}, nil
	}
	version, err := mod.ParseMODVersion(versionStr)
	if err != nil {
		return modSpec{}, err
	}
	return modSpec{MOD: mod.MOD{Name: name}, Version: version}, nil
}

// findRelease returns the release matching spec: the most recently released
// one for "latest", or the exact version otherwise.
func findRelease(info *api.MODInfo, spec modSpec) *api.Release {
	if spec.Latest {
		return latestByReleaseDate(info.Releases)
	}
	for i := range info.Releases {
		if info.Releases[i].Version == spec.Version {
			return &info.Releases[i]
		}
	}
	return nil
}

// findCompatibleRelease returns the most recently released version
// satisfying requirement (or the most recent release of any version when
// requirement is nil).
func findCompatibleRelease(info *api.MODInfo, requirement *dependency.VersionRequirement) *api.Release {
	if requirement == nil {
		return latestByReleaseDate(info.Releases)
	}
	var compatible []api.Release
	for _, r := range info.Releases {
		if requirement.SatisfiedBy(r.Version) {
			compatible = append(compatible, r)
		}
	}
	return latestByReleaseDate(compatible)
}

func latestByReleaseDate(releases []api.Release) *api.Release {
	if len(releases) == 0 {
		return nil
	}
	latest := &releases[0]
	for i := 1; i < len(releases); i++ {
		if releases[i].ReleasedAt.After(latest.ReleasedAt) {
			latest = &releases[i]
		}
	}
	return latest
}

// downloadTarget is a MOD release resolved to a local output path.
type downloadTarget struct {
	MOD        mod.MOD
	MODInfo    *api.MODInfo
	Release    api.Release
	OutputPath string
}

// validateFilename rejects a release file_name that could escape the
// intended output directory. The Portal is expected to return a plain
// filename; this guards against a compromised or malformed response.
func validateFilename(filename string) error {
	if filename == "" {
		return fmt.Errorf("%w: filename is empty", errInvalidFilename)
	}
	if strings.ContainsAny(filename, `/\`) {
		return fmt.Errorf("%w: filename contains path separators: %q", errInvalidFilename, filename)
	}
	if strings.Contains(filename, "..") {
		return fmt.Errorf("%w: filename contains parent directory reference: %q", errInvalidFilename, filename)
	}
	return nil
}

func buildDownloadTargets(infos []fetchedMODInfo, outputDir string) ([]downloadTarget, error) {
	targets := make([]downloadTarget, 0, len(infos))
	for _, info := range infos {
		if err := validateFilename(info.Release.FileName); err != nil {
			return nil, err
		}
		targets = append(targets, downloadTarget{
			MOD:        info.MOD,
			MODInfo:    info.MODInfo,
			Release:    info.Release,
			OutputPath: filepath.Join(outputDir, info.Release.FileName),
		})
	}
	return targets, nil
}

// fetchedMODInfo pairs a resolved release with its MOD and full info,
// carried through target-building and (for downloads) dependency resolution.
type fetchedMODInfo struct {
	MOD     mod.MOD
	MODInfo *api.MODInfo
	Release api.Release
}

// fetchMODInfoConcurrently resolves each spec to a release via resolve, run
// with up to jobs concurrent Portal requests.
func fetchMODInfoConcurrently(ctx context.Context, jobs int, specs []modSpec, resolve func(context.Context, modSpec) (fetchedMODInfo, error)) ([]fetchedMODInfo, error) {
	results := make([]fetchedMODInfo, len(specs))
	group, ctx := errgroup.WithContext(ctx)
	group.SetLimit(jobs)
	for i, spec := range specs {
		group.Go(func() error {
			result, err := resolve(ctx, spec)
			if err != nil {
				return err
			}
			results[i] = result
			return nil
		})
	}
	if err := group.Wait(); err != nil {
		return nil, err
	}
	return results, nil
}

// downloadTargets downloads each target to its OutputPath, up to jobs
// concurrently, with a progress bar per file on stderr when it is a
// terminal (stdout, the only e2e-compared stream, stays untouched).
func downloadTargets(ctx context.Context, application *app.App, targets []downloadTarget, jobs int) error {
	downloader, err := application.Downloader()
	if err != nil {
		return err
	}
	downloadAPI, err := application.MODDownloadAPI()
	if err != nil {
		return err
	}

	renderer := progress.NewRenderer()
	group, ctx := errgroup.WithContext(ctx)
	group.SetLimit(jobs)
	for _, target := range targets {
		group.Go(func() error {
			downloadURL, err := downloadAPI.DownloadURL(target.Release.DownloadURL)
			if err != nil {
				return err
			}
			return downloader.Download(ctx, downloadURL, target.OutputPath, transfer.DownloadOptions{
				ExpectedSHA1: target.Release.SHA1,
				Listener:     renderer.Listener(target.Release.FileName),
			})
		})
	}
	err = group.Wait()
	renderer.Wait()
	return err
}
