package api

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/url"
	"path"
	"slices"

	"github.com/sakuro/factorix/internal/httpx"
)

// Base URLs for the game download endpoints.
const (
	DefaultGameDownloadBaseURL = "https://www.factorio.com"
	DefaultGameAPIBaseURL      = "https://factorio.com"
)

// Valid build types, platforms, and release channels.
var (
	Builds    = []string{"alpha", "expansion", "demo", "headless"}
	Platforms = []string{"win64", "win64-manual", "osx", "linux64"}
	Channels  = []string{"stable", "experimental"}
)

// GameDownloadAPI talks to the game download endpoints.
//
// See https://wiki.factorio.com/Download_API
type GameDownloadAPI struct {
	Client          *httpx.Client
	Credentials     func() (ServiceCredential, error)
	Logger          *slog.Logger
	DownloadBaseURL string
	APIBaseURL      string
}

// NewGameDownloadAPI builds a game download client with the default URLs.
func NewGameDownloadAPI(client *httpx.Client, credentials func() (ServiceCredential, error), logger *slog.Logger) *GameDownloadAPI {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &GameDownloadAPI{
		Client:          client,
		Credentials:     credentials,
		Logger:          logger,
		DownloadBaseURL: DefaultGameDownloadBaseURL,
		APIBaseURL:      DefaultGameAPIBaseURL,
	}
}

// LatestReleases is the /api/latest-releases response: version strings per
// build, per channel.
type LatestReleases struct {
	Stable       map[string]string `json:"stable"`
	Experimental map[string]string `json:"experimental"`
}

// GetLatestReleases fetches the latest release versions.
func (a *GameDownloadAPI) GetLatestReleases(ctx context.Context) (*LatestReleases, error) {
	a.Logger.Debug("Fetching latest releases")
	resp, err := a.Client.Get(ctx, a.APIBaseURL+"/api/latest-releases")
	if err != nil {
		return nil, err
	}
	var releases LatestReleases
	if err := json.Unmarshal(resp.Body, &releases); err != nil {
		return nil, fmt.Errorf("%w: %s", ErrInvalidResponse, err)
	}
	return &releases, nil
}

// LatestVersion returns the latest version for a channel and build, or ""
// when not available.
func (a *GameDownloadAPI) LatestVersion(ctx context.Context, channel, build string) (string, error) {
	if err := validateOneOf("channel", channel, Channels); err != nil {
		return "", err
	}
	if err := validateOneOf("build", build, Builds); err != nil {
		return "", err
	}
	releases, err := a.GetLatestReleases(ctx)
	if err != nil {
		return "", err
	}
	switch channel {
	case "stable":
		return releases.Stable[build], nil
	default:
		return releases.Experimental[build], nil
	}
}

// ResolveFilename determines the download filename by following the
// redirect of a HEAD request and taking the final URL's basename.
func (a *GameDownloadAPI) ResolveFilename(ctx context.Context, version, build, platform string) (string, error) {
	downloadURL, err := a.DownloadURL(version, build, platform)
	if err != nil {
		return "", err
	}
	resp, err := a.Client.Head(ctx, downloadURL)
	if err != nil {
		return "", err
	}
	return path.Base(resp.URL.Path), nil
}

// DownloadURL builds the authenticated download URL for a game build; the
// download itself is performed by internal/transfer.
func (a *GameDownloadAPI) DownloadURL(version, build, platform string) (string, error) {
	if err := validateOneOf("build", build, Builds); err != nil {
		return "", err
	}
	if err := validateOneOf("platform", platform, Platforms); err != nil {
		return "", err
	}
	credential, err := a.Credentials()
	if err != nil {
		return "", err
	}
	params := url.Values{}
	params.Set("username", credential.Username())
	params.Set("token", credential.Token())
	return fmt.Sprintf("%s/get-download/%s/%s/%s?%s", a.DownloadBaseURL, version, build, platform, params.Encode()), nil
}

func validateOneOf(name, value string, valid []string) error {
	if slices.Contains(valid, value) {
		return nil
	}
	return fmt.Errorf("%w: invalid %s: %q (valid: %v)", ErrInvalidArgument, name, value, valid)
}
