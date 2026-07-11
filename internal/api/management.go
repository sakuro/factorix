package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"maps"
	"net/http"
	"net/url"
	"slices"
	"strconv"
	"strings"

	"github.com/sakuro/factorix/internal/httpx"
)

// Uploader performs multipart file uploads; implemented by
// internal/transfer in Phase 8. fields are extra form fields, fieldName is
// the file's form field (defaults to "file" when empty).
type Uploader interface {
	Upload(ctx context.Context, uploadURL, filePath string, fields map[string]string, fieldName string) ([]byte, error)
}

// Metadata fields accepted by FinishUpload (init_publish scenario only).
// EditDetails needs no equivalent: its metadata is the typed EditMetadata
// struct, so the compiler rejects unknown fields instead of a runtime check.
var allowedUploadMetadata = []string{"description", "category", "license", "source_url"}

// MODManagementAPI performs portal operations that require an API key:
// publishing, uploading releases, editing details and images.
//
// See https://wiki.factorio.com/Mod_upload_API
type MODManagementAPI struct {
	Client   *httpx.Client
	Uploader Uploader
	Logger   *slog.Logger
	BaseURL  string
	// Credentials resolves the API key lazily so FACTORIO_API_KEY is only
	// required when a management operation actually runs.
	Credentials func() (APICredential, error)
	// OnMODChanged is invoked with the MOD name after any operation that
	// changes the MOD on the portal; wired to MODPortalAPI's cache
	// invalidation. This replaces the Ruby dry-events subscription.
	OnMODChanged func(ctx context.Context, name string)
}

// NewMODManagementAPI builds a management client with the default base URL.
func NewMODManagementAPI(client *httpx.Client, uploader Uploader, credentials func() (APICredential, error), logger *slog.Logger) *MODManagementAPI {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &MODManagementAPI{
		Client:      client,
		Uploader:    uploader,
		Logger:      logger,
		BaseURL:     DefaultPortalBaseURL,
		Credentials: credentials,
	}
}

// InitPublish starts publication of a brand-new MOD and returns the upload URL.
func (a *MODManagementAPI) InitPublish(ctx context.Context, name string) (string, error) {
	a.Logger.Info("Initializing MOD publication", "mod", name)
	return a.initUpload(ctx, "/api/v2/mods/init_publish", name)
}

// InitUpload starts a release upload to an existing MOD and returns the
// upload URL.
func (a *MODManagementAPI) InitUpload(ctx context.Context, name string) (string, error) {
	a.Logger.Info("Initializing MOD upload", "mod", name)
	uploadURL, err := a.initUpload(ctx, "/api/v2/mods/releases/init_upload", name)
	if err != nil {
		return "", mapNotFound(err, name)
	}
	return uploadURL, nil
}

// FinishUpload uploads the MOD file to the URL from InitPublish/InitUpload.
// metadata is only meaningful for the publish scenario.
func (a *MODManagementAPI) FinishUpload(ctx context.Context, name, uploadURL, filePath string, metadata map[string]string) error {
	if err := validateMetadataKeys(keysOf(metadata), allowedUploadMetadata, "FinishUpload"); err != nil {
		return err
	}
	a.Logger.Info("Uploading MOD file", "mod", name, "file", filePath, "metadata_count", len(metadata))
	if _, err := a.Uploader.Upload(ctx, uploadURL, filePath, metadata, ""); err != nil {
		return err
	}
	a.Logger.Info("Upload completed successfully", "mod", name)
	a.notifyChanged(ctx, name)
	return nil
}

// EditMetadata is the metadata accepted by EditDetails. Only non-zero
// fields are sent; Deprecated needs the pointer to distinguish "unset"
// from "set to false".
type EditMetadata struct {
	Description string
	Summary     string
	Title       string
	Category    string
	Tags        []string
	License     string
	Homepage    string
	SourceURL   string
	FAQ         string
	Deprecated  *bool
}

func (m EditMetadata) formValues() url.Values {
	values := url.Values{}
	set := func(key, value string) {
		if value != "" {
			values.Set(key, value)
		}
	}
	set("description", m.Description)
	set("summary", m.Summary)
	set("title", m.Title)
	set("category", m.Category)
	for _, tag := range m.Tags {
		values.Add("tags", tag)
	}
	set("license", m.License)
	set("homepage", m.Homepage)
	set("source_url", m.SourceURL)
	set("faq", m.FAQ)
	if m.Deprecated != nil {
		values.Set("deprecated", strconv.FormatBool(*m.Deprecated))
	}
	return values
}

// EditDetails updates a MOD's metadata on the portal.
func (a *MODManagementAPI) EditDetails(ctx context.Context, name string, metadata EditMetadata) error {
	form := metadata.formValues()
	a.Logger.Info("Editing MOD details", "mod", name, "fields", len(form))
	form.Set("mod", name)

	if _, err := a.postForm(ctx, "/api/v2/mods/edit_details", form); err != nil {
		return mapNotFound(err, name)
	}
	a.Logger.Info("Edit completed successfully", "mod", name)
	a.notifyChanged(ctx, name)
	return nil
}

// InitImageUpload starts an image upload and returns the upload URL.
func (a *MODManagementAPI) InitImageUpload(ctx context.Context, name string) (string, error) {
	a.Logger.Info("Initializing image upload", "mod", name)
	uploadURL, err := a.initUpload(ctx, "/api/v2/mods/images/add", name)
	if err != nil {
		return "", mapNotFound(err, name)
	}
	return uploadURL, nil
}

// FinishImageUpload uploads the image to the URL from InitImageUpload and
// returns the created image.
func (a *MODManagementAPI) FinishImageUpload(ctx context.Context, name, uploadURL, imagePath string) (Image, error) {
	a.Logger.Info("Uploading image file", "mod", name, "file", imagePath)
	body, err := a.Uploader.Upload(ctx, uploadURL, imagePath, nil, "image")
	if err != nil {
		return Image{}, err
	}
	var image Image
	if err := json.Unmarshal(body, &image); err != nil {
		return Image{}, fmt.Errorf("%w: %s", ErrInvalidResponse, err)
	}
	a.Logger.Info("Image upload completed successfully", "mod", name, "image_id", image.ID)
	a.notifyChanged(ctx, name)
	return image, nil
}

// EditImages replaces the MOD's image list with the given IDs, in order.
func (a *MODManagementAPI) EditImages(ctx context.Context, name string, imageIDs []string) error {
	form := url.Values{}
	form.Set("mod", name)
	form.Set("images", strings.Join(imageIDs, ","))

	a.Logger.Info("Editing MOD images", "mod", name, "image_count", len(imageIDs))
	if _, err := a.postForm(ctx, "/api/v2/mods/images/edit", form); err != nil {
		return mapNotFound(err, name)
	}
	a.Logger.Info("Images updated successfully", "mod", name)
	a.notifyChanged(ctx, name)
	return nil
}

func (a *MODManagementAPI) initUpload(ctx context.Context, endpoint, name string) (string, error) {
	form := url.Values{}
	form.Set("mod", name)
	resp, err := a.postForm(ctx, endpoint, form)
	if err != nil {
		return "", err
	}
	var result struct {
		UploadURL string `json:"upload_url"`
	}
	if err := json.Unmarshal(resp.Body, &result); err != nil {
		return "", fmt.Errorf("%w: %s", ErrInvalidResponse, err)
	}
	if result.UploadURL == "" {
		return "", fmt.Errorf("%w: missing upload_url", ErrInvalidResponse)
	}
	return result.UploadURL, nil
}

func (a *MODManagementAPI) postForm(ctx context.Context, endpoint string, form url.Values) (*httpx.Response, error) {
	credential, err := a.Credentials()
	if err != nil {
		return nil, err
	}
	header := http.Header{}
	header.Set("Authorization", "Bearer "+credential.APIKey())
	header.Set("Content-Type", "application/x-www-form-urlencoded")
	return a.Client.Request(ctx, http.MethodPost, a.BaseURL+endpoint, header, strings.NewReader(form.Encode()))
}

func (a *MODManagementAPI) notifyChanged(ctx context.Context, name string) {
	if a.OnMODChanged != nil {
		a.OnMODChanged(ctx, name)
	}
}

func mapNotFound(err error, name string) error {
	var statusErr *httpx.StatusError
	if errors.As(err, &statusErr) && statusErr.IsNotFound() {
		return fmt.Errorf("%w: %s", ErrMODNotOnPortal, name)
	}
	return err
}

func validateMetadataKeys(keys, allowed []string, context string) error {
	for _, key := range keys {
		if !slices.Contains(allowed, key) {
			return fmt.Errorf("%w: invalid metadata for %s: %s (allowed: %v)", ErrInvalidArgument, context, key, allowed)
		}
	}
	return nil
}

func keysOf(m map[string]string) []string {
	return slices.Collect(maps.Keys(m))
}
