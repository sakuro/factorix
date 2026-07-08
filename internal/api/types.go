// Package api implements the Factorio MOD Portal and game download API
// clients.
//
// See https://wiki.factorio.com/Mod_portal_API
package api

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/sakuro/factorix/internal/mod"
)

// License describes a MOD license.
type License struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Title       string `json:"title"`
	Description string `json:"description"`
	URL         string `json:"url"`
}

// Image is one entry of a MOD's image gallery.
type Image struct {
	ID        string `json:"id"`
	Thumbnail string `json:"thumbnail"`
	URL       string `json:"url"`
}

// ReleaseInfoJSON is the subset of info.json the portal includes per release.
type ReleaseInfoJSON struct {
	FactorioVersion string   `json:"factorio_version"`
	Dependencies    []string `json:"dependencies"`
}

// Release is one version of a MOD published on the portal.
type Release struct {
	DownloadURL  string          `json:"download_url"` // relative path
	FileName     string          `json:"file_name"`
	InfoJSON     ReleaseInfoJSON `json:"info_json"`
	ReleasedAt   time.Time       `json:"released_at"`
	Version      mod.MODVersion  `json:"-"`
	SHA1         string          `json:"sha1"`
	FeatureFlags []string        `json:"feature_flags"`

	// versionInvalid marks releases whose version string cannot be
	// represented (components over 255 — such MODs exist on the Portal).
	// The API clients drop them after decoding.
	versionInvalid bool
	rawVersion     string
}

// UnmarshalJSON decodes a release, tolerating out-of-range version strings
// so a single odd release does not fail the whole MOD.
func (r *Release) UnmarshalJSON(data []byte) error {
	type alias Release
	raw := struct {
		*alias
		Version string `json:"version"`
	}{alias: (*alias)(r)}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	r.rawVersion = raw.Version
	version, err := mod.ParseMODVersion(raw.Version)
	if err != nil {
		r.versionInvalid = true
		return nil
	}
	r.Version = version
	return nil
}

// Pagination describes the paging of a MOD list response.
type Pagination struct {
	Count     int `json:"count"`
	Page      int `json:"page"`
	PageCount int `json:"page_count"`
	PageSize  int `json:"page_size"`
}

// MODInfo is MOD metadata from the portal. The detail fields (Changelog
// through Deprecated) are only populated by the full endpoint.
type MODInfo struct {
	Name           string    `json:"name"`
	Title          string    `json:"title"`
	Owner          string    `json:"owner"`
	Summary        string    `json:"summary"`
	DownloadsCount int       `json:"downloads_count"`
	Category       string    `json:"category"`
	Score          float64   `json:"score"`
	Thumbnail      string    `json:"thumbnail"` // relative asset path
	LatestRelease  *Release  `json:"latest_release"`
	Releases       []Release `json:"releases"`

	Changelog         string    `json:"changelog"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
	LastHighlightedAt time.Time `json:"last_highlighted_at"`
	Description       string    `json:"description"`
	SourceURL         string    `json:"source_url"`
	Homepage          string    `json:"homepage"`
	FAQ               string    `json:"faq"`
	Tags              []string  `json:"tags"`
	License           *License  `json:"license"`
	Images            []Image   `json:"images"`
	Deprecated        bool      `json:"deprecated"`
}

// UnmarshalJSON decodes MOD info. LastHighlightedAt gets its own pass: the
// Portal represents it as either a full RFC3339 timestamp or a bare
// "2006-01-02" date — both valid ISO 8601, but only the former is valid
// RFC3339, which is all time.Time's own UnmarshalJSON accepts.
// CreatedAt/UpdatedAt are always full timestamps in observed Portal
// responses and keep the standard time.Time decoding.
func (m *MODInfo) UnmarshalJSON(data []byte) error {
	type alias MODInfo
	raw := struct {
		*alias
		LastHighlightedAt string `json:"last_highlighted_at"`
	}{alias: (*alias)(m)}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	if raw.LastHighlightedAt == "" {
		return nil
	}
	t, err := time.Parse(time.RFC3339, raw.LastHighlightedAt)
	if err != nil {
		if t, err = time.Parse("2006-01-02", raw.LastHighlightedAt); err != nil {
			return fmt.Errorf("%w: cannot parse last_highlighted_at %q", ErrInvalidResponse, raw.LastHighlightedAt)
		}
	}
	m.LastHighlightedAt = t
	return nil
}

// ThumbnailURL returns the absolute thumbnail URL, or "" when absent.
func (m *MODInfo) ThumbnailURL() string {
	if m.Thumbnail == "" {
		return ""
	}
	return "https://assets-mod.factorio.com" + m.Thumbnail
}

// MODsPage is one page of a MOD list response.
type MODsPage struct {
	Results    []MODInfo  `json:"results"`
	Pagination Pagination `json:"pagination"`
}
