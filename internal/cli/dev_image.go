package cli

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/api"
)

func newDevImageCommand(c *cli) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "image",
		Short: "Manage MOD images",
	}
	cmd.AddCommand(
		newDevImageListCommand(c),
		newDevImageAddCommand(c),
		newDevImageEditCommand(c),
	)
	return cmd
}

func newDevImageListCommand(c *cli) *cobra.Command {
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "list <mod-name>",
		Short: "List images for a MOD",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}
			portal, err := application.PortalAPI()
			if err != nil {
				return err
			}
			info, err := portal.GetMODFull(cmd.Context(), args[0])
			if err != nil {
				return err
			}

			p := c.printer(cmd)
			if jsonOutput {
				return outputImageJSON(p, info.Images)
			}
			outputImageTable(p, info.Images)
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output in JSON format")
	return cmd
}

func outputImageTable(p *printer, images []api.Image) {
	if len(images) == 0 {
		p.Info("No images found")
		return
	}

	idWidth, thumbWidth := len("ID"), len("THUMBNAIL")
	for _, image := range images {
		idWidth = max(idWidth, len(image.ID))
		thumbWidth = max(thumbWidth, len(image.Thumbnail))
	}
	p.Printf("%-*s  %-*s  %s\n", idWidth, "ID", thumbWidth, "THUMBNAIL", "URL")
	for _, image := range images {
		p.Printf("%-*s  %-*s  %s\n", idWidth, image.ID, thumbWidth, image.Thumbnail, image.URL)
	}
}

func outputImageJSON(p *printer, images []api.Image) error {
	type imageEntry struct {
		ID        string `json:"id"`
		Thumbnail string `json:"thumbnail"`
		URL       string `json:"url"`
	}
	entries := make([]imageEntry, 0, len(images))
	for _, image := range images {
		entries = append(entries, imageEntry{ID: image.ID, Thumbnail: image.Thumbnail, URL: image.URL})
	}
	data, err := json.MarshalIndent(entries, "", "  ")
	if err != nil {
		return err
	}
	p.Println(string(data))
	return nil
}

func newDevImageAddCommand(c *cli) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "add <mod-name> <image-file>",
		Short: "Add an image to a MOD",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			name, imageFile := args[0], args[1]
			if _, err := os.Stat(imageFile); errors.Is(err, os.ErrNotExist) {
				return fmt.Errorf("Image file not found: %s", imageFile)
			} else if err != nil {
				return err
			}

			application, err := c.App()
			if err != nil {
				return err
			}
			management, err := application.ManagementAPI()
			if err != nil {
				return err
			}
			uploadURL, err := management.InitImageUpload(cmd.Context(), name)
			if err != nil {
				return err
			}
			image, err := management.FinishImageUpload(cmd.Context(), name, uploadURL, imageFile)
			if err != nil {
				return err
			}

			p := c.printer(cmd)
			p.Success("Image added successfully!")
			p.Say("  ID: " + image.ID)
			p.Say("  Thumbnail: " + image.Thumbnail)
			p.Say("  Full URL: " + image.URL)
			return nil
		},
	}
	return cmd
}

func newDevImageEditCommand(c *cli) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "edit <mod-name> <image-id>...",
		Short: "Edit MOD's image list (reorder/remove images)",
		Args:  cobra.MinimumNArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			name, imageIDs := args[0], args[1:]

			application, err := c.App()
			if err != nil {
				return err
			}
			management, err := application.ManagementAPI()
			if err != nil {
				return err
			}
			if err := management.EditImages(cmd.Context(), name, imageIDs); err != nil {
				return err
			}

			p := c.printer(cmd)
			p.Success("Image list updated successfully!")
			p.Info(fmt.Sprintf("Total images: %d", len(imageIDs)))
			return nil
		},
	}
	return cmd
}
