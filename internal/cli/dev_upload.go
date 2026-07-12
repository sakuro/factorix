package cli

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/mod"
)

func newDevUploadCommand(c *cli) *cobra.Command {
	var description, category, license, sourceURL string

	cmd := &cobra.Command{
		Use:   "upload <file>",
		Short: "Upload MOD to Factorio MOD Portal (handles both new and update)",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			file := args[0]
			if err := validateUploadFile(file); err != nil {
				return err
			}
			info, err := mod.InfoJSONFromZIP(file)
			if err != nil {
				return err
			}

			application, err := c.App()
			if err != nil {
				return err
			}
			metadata := map[string]string{}
			for key, value := range map[string]string{
				"description": description,
				"category":    category,
				"license":     license,
				"source_url":  sourceURL,
			} {
				if value != "" {
					metadata[key] = value
				}
			}

			if err := uploadMOD(cmd.Context(), application, info.Name, file, metadata); err != nil {
				return err
			}
			c.printer(cmd).Success("Upload completed successfully!")
			return nil
		},
	}
	cmd.Flags().StringVar(&description, "description", "", "Markdown description")
	cmd.Flags().StringVar(&category, "category", "", "MOD category")
	cmd.Flags().StringVar(&license, "license", "", "License identifier")
	cmd.Flags().StringVar(&sourceURL, "source-url", "", "Repository URL")
	return cmd
}

func validateUploadFile(file string) error {
	stat, err := os.Stat(file)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("File not found: %s", file)
		}
		return err
	}
	if stat.IsDir() {
		return fmt.Errorf("Not a file: %s", file)
	}
	if !strings.EqualFold(filepath.Ext(file), ".zip") {
		return fmt.Errorf("File must be a .zip file")
	}
	return nil
}

// uploadMOD mirrors Ruby's Portal#upload_mod: an existing MOD gets a
// release upload followed by a separate metadata edit; a new MOD is
// published with the metadata included in the upload itself.
func uploadMOD(ctx context.Context, application *app.App, name, file string, metadata map[string]string) error {
	portal, err := application.PortalAPI()
	if err != nil {
		return err
	}
	management, err := application.ManagementAPI()
	if err != nil {
		return err
	}

	exists := true
	if _, err := portal.GetMOD(ctx, name); err != nil {
		if !errors.Is(err, api.ErrMODNotOnPortal) {
			return err
		}
		exists = false
	}

	if !exists {
		uploadURL, err := management.InitPublish(ctx, name)
		if err != nil {
			return err
		}
		return management.FinishUpload(ctx, name, uploadURL, file, metadata)
	}

	uploadURL, err := management.InitUpload(ctx, name)
	if err != nil {
		return err
	}
	if err := management.FinishUpload(ctx, name, uploadURL, file, nil); err != nil {
		return err
	}
	if len(metadata) == 0 {
		return nil
	}
	return management.EditDetails(ctx, name, api.EditMetadata{
		Description: metadata["description"],
		Category:    metadata["category"],
		License:     metadata["license"],
		SourceURL:   metadata["source_url"],
	})
}
