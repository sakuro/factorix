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
	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/progress"
	"github.com/sakuro/factorix/internal/resolver"
	"github.com/sakuro/factorix/internal/transfer"
)

var errInvalidFilename = errors.New("invalid filename")

// parseMODSpec parses a MOD specification. "latest" and the bare name both
// mean the latest release.
func parseMODSpec(spec string) (resolver.Spec, error) {
	name, versionStr, hasVersion := strings.Cut(spec, "@")
	if !hasVersion || versionStr == "" || versionStr == "latest" {
		return resolver.Spec{MOD: mod.MOD{Name: name}, Latest: true}, nil
	}
	version, err := mod.ParseMODVersion(versionStr)
	if err != nil {
		return resolver.Spec{}, err
	}
	return resolver.Spec{MOD: mod.MOD{Name: name}, Version: version}, nil
}

// downloadTarget is a MOD release resolved to a local output path.
type downloadTarget struct {
	MOD        mod.MOD
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

func buildDownloadTargets(fetched []resolver.Fetched, outputDir string) ([]downloadTarget, error) {
	targets := make([]downloadTarget, 0, len(fetched))
	for _, f := range fetched {
		if err := validateFilename(f.Release.FileName); err != nil {
			return nil, err
		}
		targets = append(targets, downloadTarget{
			MOD:        f.MOD,
			Release:    f.Release,
			OutputPath: filepath.Join(outputDir, f.Release.FileName),
		})
	}
	return targets, nil
}

// releaseDownloadTargets converts a Resolve result into download targets
// (order follows map iteration; downloads run concurrently anyway).
func releaseDownloadTargets(releases map[mod.MOD]api.Release, outputDir string) ([]downloadTarget, error) {
	targets := make([]downloadTarget, 0, len(releases))
	for m, release := range releases {
		if err := validateFilename(release.FileName); err != nil {
			return nil, err
		}
		targets = append(targets, downloadTarget{
			MOD:        m,
			Release:    release,
			OutputPath: filepath.Join(outputDir, release.FileName),
		})
	}
	return targets, nil
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
