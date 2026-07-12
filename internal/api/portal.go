package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/url"
	"slices"
	"strconv"

	"github.com/sakuro/factorix/internal/cache"
	"github.com/sakuro/factorix/internal/httpx"
)

// DefaultPortalBaseURL is the MOD Portal endpoint.
const DefaultPortalBaseURL = "https://mods.factorio.com"

// MODPortalAPI retrieves MOD lists and details. No authentication is
// required; response caching is provided by the client's CacheTransport,
// and Cache is used to invalidate entries after portal-changing operations.
type MODPortalAPI struct {
	Client  *httpx.Client
	Cache   cache.Cache
	Logger  *slog.Logger
	BaseURL string
}

// NewMODPortalAPI builds a portal client with the default base URL.
func NewMODPortalAPI(client *httpx.Client, apiCache cache.Cache, logger *slog.Logger) *MODPortalAPI {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &MODPortalAPI{Client: client, Cache: apiCache, Logger: logger, BaseURL: DefaultPortalBaseURL}
}

// GetMODsOptions filters and pages the MOD list.
type GetMODsOptions struct {
	Namelist       []string
	HideDeprecated *bool
	Page           int    // 0 = unset
	PageSize       string // "", a positive integer, or "max"
	Sort           string // "", name, created_at, updated_at
	SortOrder      string // "", asc, desc
	Version        string // "", or a Factorio version like "2.0"
}

var (
	validSorts    = []string{"name", "created_at", "updated_at"}
	validOrders   = []string{"asc", "desc"}
	validVersions = []string{"0.13", "0.14", "0.15", "0.16", "0.17", "0.18", "1.0", "1.1", "2.0", "2.1"}
)

func (o GetMODsOptions) validate() error {
	if o.PageSize != "" && o.PageSize != "max" {
		if n, err := strconv.Atoi(o.PageSize); err != nil || n <= 0 {
			return fmt.Errorf("%w: page_size must be a positive integer or \"max\", got %q", ErrInvalidArgument, o.PageSize)
		}
	}
	if o.Sort != "" && !slices.Contains(validSorts, o.Sort) {
		return fmt.Errorf("%w: sort must be one of %v, got %q", ErrInvalidArgument, validSorts, o.Sort)
	}
	if o.SortOrder != "" && !slices.Contains(validOrders, o.SortOrder) {
		return fmt.Errorf("%w: sort_order must be one of %v, got %q", ErrInvalidArgument, validOrders, o.SortOrder)
	}
	if o.Version != "" && !slices.Contains(validVersions, o.Version) {
		return fmt.Errorf("%w: version must be one of %v, got %q", ErrInvalidArgument, validVersions, o.Version)
	}
	return nil
}

// query builds the sorted query string; url.Values.Encode sorts keys, which
// keeps cache keys stable for equivalent requests.
func (o GetMODsOptions) query() string {
	params := url.Values{}
	namelist := slices.Clone(o.Namelist)
	slices.Sort(namelist)
	for _, name := range namelist {
		params.Add("namelist", name)
	}
	if o.HideDeprecated != nil {
		params.Set("hide_deprecated", strconv.FormatBool(*o.HideDeprecated))
	}
	if o.Page > 0 {
		params.Set("page", strconv.Itoa(o.Page))
	}
	if o.PageSize != "" {
		params.Set("page_size", o.PageSize)
	}
	if o.Sort != "" {
		params.Set("sort", o.Sort)
	}
	if o.SortOrder != "" {
		params.Set("sort_order", o.SortOrder)
	}
	if o.Version != "" {
		params.Set("version", o.Version)
	}
	return params.Encode()
}

// GetMODs retrieves one page of the MOD list.
func (a *MODPortalAPI) GetMODs(ctx context.Context, opts GetMODsOptions) (*MODsPage, error) {
	if err := opts.validate(); err != nil {
		return nil, err
	}
	requestURL := a.BaseURL + "/api/mods"
	if query := opts.query(); query != "" {
		requestURL += "?" + query
	}
	a.Logger.Debug("Fetching MOD list", "url", requestURL)

	var page MODsPage
	if err := a.getJSON(ctx, requestURL, &page); err != nil {
		return nil, err
	}
	for i := range page.Results {
		a.pruneInvalidReleases(&page.Results[i])
	}
	return &page, nil
}

// GetMOD retrieves basic information for a MOD (the short endpoint).
func (a *MODPortalAPI) GetMOD(ctx context.Context, name string) (*MODInfo, error) {
	return a.getMOD(ctx, name, a.modURL(name))
}

// GetMODFull retrieves full information for a MOD, including the detail
// fields and the full Releases list. Confirmed against the live API:
// MODInfo.LatestRelease is nil in this response (the Portal API wiki never
// documents this, or how "latest" would even be chosen) — callers that
// need a "latest" release must derive it from Releases themselves.
func (a *MODPortalAPI) GetMODFull(ctx context.Context, name string) (*MODInfo, error) {
	return a.getMOD(ctx, name, a.modFullURL(name))
}

func (a *MODPortalAPI) getMOD(ctx context.Context, name, requestURL string) (*MODInfo, error) {
	a.Logger.Debug("Fetching MOD", "name", name, "url", requestURL)
	var info MODInfo
	if err := a.getJSON(ctx, requestURL, &info); err != nil {
		var statusErr *httpx.StatusError
		if errors.As(err, &statusErr) && statusErr.IsNotFound() {
			return nil, fmt.Errorf("%w: %s", ErrMODNotOnPortal, name)
		}
		return nil, err
	}
	a.pruneInvalidReleases(&info)
	return &info, nil
}

// InvalidateMODCache removes the cached short and full responses for a MOD,
// typically after it changed on the portal. Wired as MODManagementAPI's
// OnMODChanged callback.
func (a *MODPortalAPI) InvalidateMODCache(ctx context.Context, name string) error {
	for _, key := range []string{a.modURL(name), a.modFullURL(name)} {
		err := a.Cache.WithLock(ctx, key, func() error {
			_, err := a.Cache.Delete(ctx, key)
			return err
		})
		if err != nil {
			return err
		}
	}
	a.Logger.Debug("Invalidated cache for MOD", "mod", name)
	return nil
}

func (a *MODPortalAPI) modURL(name string) string {
	return a.BaseURL + "/api/mods/" + url.PathEscape(name)
}

func (a *MODPortalAPI) modFullURL(name string) string {
	return a.modURL(name) + "/full"
}

func (a *MODPortalAPI) getJSON(ctx context.Context, requestURL string, target any) error {
	resp, err := a.Client.Get(ctx, requestURL)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(resp.Body, target); err != nil {
		return fmt.Errorf("%w: %s", ErrInvalidResponse, err)
	}
	return nil
}

// pruneInvalidReleases drops releases whose version could not be
// represented; a MOD with such a release should still be usable.
func (a *MODPortalAPI) pruneInvalidReleases(info *MODInfo) {
	info.Releases = slices.DeleteFunc(info.Releases, func(r Release) bool {
		if r.versionInvalid {
			a.Logger.Warn("Skipping release with unsupported version", "mod", info.Name, "version", r.rawVersion)
		}
		return r.versionInvalid
	})
	if info.LatestRelease != nil && info.LatestRelease.versionInvalid {
		a.Logger.Warn("Skipping latest release with unsupported version", "mod", info.Name, "version", info.LatestRelease.rawVersion)
		info.LatestRelease = nil
	}
}
