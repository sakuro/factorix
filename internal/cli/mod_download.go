package cli

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/resolver"
)

func newMODDownloadCommand(c *cli) *cobra.Command {
	var directory string
	var jobs int
	var recursive, ignoreRecommended bool

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

			specs := make([]resolver.Spec, len(args))
			for i, arg := range args {
				spec, err := parseMODSpec(arg)
				if err != nil {
					return err
				}
				specs[i] = spec
			}

			targets, err := planDownload(cmd.Context(), application, specs, downloadDir, jobs, recursive, !ignoreRecommended)
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
	cmd.Flags().BoolVarP(&recursive, "recursive", "r", false, "Include dependencies recursively (required and recommended)")
	cmd.Flags().BoolVar(&ignoreRecommended, "ignore-recommended", false, "Do not resolve recommended dependencies")
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

func planDownload(ctx context.Context, application *app.App, specs []resolver.Spec, downloadDir string, jobs int, recursive, includeRecommended bool) ([]downloadTarget, error) {
	portalAPI, err := application.PortalAPI()
	if err != nil {
		return nil, err
	}
	res := &resolver.Resolver{Portal: portalAPI, Logger: application.Logger}

	if !recursive {
		fetched, err := res.Fetch(ctx, specs, jobs)
		if err != nil {
			return nil, err
		}
		return buildDownloadTargets(fetched, downloadDir)
	}

	// Installation state is irrelevant to a plain download, so resolution
	// runs against an empty graph: every dependency counts as missing.
	releases, err := res.Resolve(ctx, dependency.NewGraph(), specs, resolver.Options{Jobs: jobs, FollowRecommended: includeRecommended})
	if err != nil {
		return nil, err
	}
	return releaseDownloadTargets(releases, downloadDir)
}
