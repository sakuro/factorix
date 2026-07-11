package cli

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/transfer"
)

// downloadPlatformMap maps the runtime platform name to the download API's
// platform identifier.
var downloadPlatformMap = map[string]string{
	"MacOS":   "osx",
	"Linux":   "linux64",
	"Windows": "win64",
	"WSL":     "win64",
}

// The download API serves nothing older than 2.0.
const minimumGameMajorVersion = 2

func newDownloadCommand(c *cli) *cobra.Command {
	var build, platform, channel, directory, output string

	cmd := &cobra.Command{
		Use:   "download [version]",
		Short: "Download Factorio game files",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			version := "latest"
			if len(args) > 0 {
				version = args[0]
			}

			application, err := c.App()
			if err != nil {
				return err
			}
			if platform == "" {
				name := application.Runtime.PlatformName()
				platform = downloadPlatformMap[name]
				if platform == "" {
					return fmt.Errorf("Cannot auto-detect platform for %s", name)
				}
			}

			gameDownload, err := application.GameDownloadAPI()
			if err != nil {
				return err
			}
			resolved, err := resolveGameVersion(cmd, gameDownload, version, channel, build)
			if err != nil {
				return err
			}

			downloadDir, err := filepath.Abs(directory)
			if err != nil {
				return err
			}
			if _, err := os.Stat(downloadDir); errors.Is(err, os.ErrNotExist) {
				return fmt.Errorf("Download directory does not exist: %s", downloadDir)
			} else if err != nil {
				return err
			}

			filename := output
			if filename == "" {
				filename, err = gameDownload.ResolveFilename(cmd.Context(), resolved, build, platform)
				if err != nil {
					return err
				}
			}
			outputPath := filepath.Join(downloadDir, filename)

			p := c.printer(cmd)
			p.Info(fmt.Sprintf("Downloading Factorio %s (%s/%s)...", resolved, build, platform))

			downloadURL, err := gameDownload.DownloadURL(resolved, build, platform)
			if err != nil {
				return err
			}
			downloader, err := application.Downloader()
			if err != nil {
				return err
			}
			if err := downloader.Download(cmd.Context(), downloadURL, outputPath, transfer.DownloadOptions{}); err != nil {
				return err
			}

			p.Success("Downloaded to " + outputPath)
			return nil
		},
	}
	cmd.Flags().StringVarP(&build, "build", "b", "alpha", "Build type")
	cmd.Flags().StringVarP(&platform, "platform", "p", "", "Platform (default: auto-detect)")
	// Ruby aliases -c to --channel here, but that collides with the global
	// --config-path shorthand, which cobra rejects; channel is long-form only.
	cmd.Flags().StringVar(&channel, "channel", "stable", "Release channel")
	cmd.Flags().StringVarP(&directory, "directory", "d", ".", "Download directory")
	cmd.Flags().StringVarP(&output, "output", "o", "", "Output filename (default: from server)")
	return cmd
}

// resolveGameVersion turns "latest" into a concrete version via the API and
// enforces the version format and the 2.0 minimum.
func resolveGameVersion(cmd *cobra.Command, gameDownload *api.GameDownloadAPI, version, channel, build string) (string, error) {
	resolved := version
	if version == "latest" {
		v, err := gameDownload.LatestVersion(cmd.Context(), channel, build)
		if err != nil {
			return "", err
		}
		if v == "" {
			return "", fmt.Errorf("No %s version available for %s", channel, build)
		}
		resolved = v
	}

	gameVersion, err := mod.ParseGameVersion(resolved)
	if err != nil {
		return "", fmt.Errorf("Invalid version format: %s", err)
	}
	if gameVersion.Major < minimumGameMajorVersion {
		return "", fmt.Errorf("Version %s is not supported. Minimum version is %d.0.0", resolved, minimumGameMajorVersion)
	}
	return resolved, nil
}
