package cli

import (
	"crypto/x509"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/sakuro/factorix/internal/httpx"
)

// portalMOD is a fixture MOD served by mockPortal. Handlers respond with
// the same JSON at both the short (/api/mods/<name>) and full
// (/api/mods/<name>/full) endpoints — real Factorix commands only need the
// fields relevant to what they're testing.
type portalMOD struct {
	Name          string          `json:"name"`
	Title         string          `json:"title"`
	Owner         string          `json:"owner"`
	Summary       string          `json:"summary,omitempty"`
	Category      string          `json:"category,omitempty"`
	LatestRelease *portalRelease  `json:"latest_release,omitempty"`
	Releases      []portalRelease `json:"releases,omitempty"`
	Images        []portalImage   `json:"images,omitempty"`
}

type portalRelease struct {
	Version     string `json:"version"`
	DownloadURL string `json:"download_url,omitempty"`
	FileName    string `json:"file_name,omitempty"`
	SHA1        string `json:"sha1,omitempty"`
	// ReleasedAt defaults to a fixed timestamp (not omitted) since
	// api.Release always decodes it as time.Time — an absent or empty
	// value fails to parse, unlike the other fields here.
	ReleasedAt string         `json:"released_at"`
	InfoJSON   portalInfoJSON `json:"info_json"`
}

type portalInfoJSON struct {
	FactorioVersion string   `json:"factorio_version"`
	Dependencies    []string `json:"dependencies"`
}

// mockPortal is an httptest server standing in for mods.factorio.com. Its
// URL must be set as FACTORIX_MODS_PORTAL_URL for a command under test to
// reach it (see withPortal).
type mockPortal struct {
	server *httptest.Server
	mods   map[string]portalMOD
	// downloads records requested download paths (the part after
	// BaseURL), so tests can assert what was fetched.
	downloads []string
	// fileContent is served for any /download/... path not in downloads.
	fileContent []byte

	// managementCalls records every /api/v2/mods/... request received, in
	// order, for assertions on what a management command actually sent.
	managementCalls []managementCall
	// imageUploadResponse is returned by finish-upload for an image
	// upload; tests set the ID/Thumbnail/URL they expect back.
	imageUploadResponse portalImage
}

// managementCall is one recorded request to a management (API-key) endpoint.
type managementCall struct {
	Path   string
	Auth   string
	Form   map[string][]string // parsed application/x-www-form-urlencoded body
	MODArg string              // convenience: Form["mod"][0], when present
}

type portalImage struct {
	ID        string `json:"id"`
	Thumbnail string `json:"thumbnail"`
	URL       string `json:"url"`
}

func newMockPortal(t *testing.T, mods ...portalMOD) *mockPortal {
	t.Helper()
	p := &mockPortal{mods: map[string]portalMOD{}, fileContent: []byte("fake-mod-zip-content")}
	for _, m := range mods {
		fillReleaseDefaults(&m)
		p.mods[m.Name] = m
	}
	p.server = httptest.NewTLSServer(http.HandlerFunc(p.handle))
	t.Cleanup(p.server.Close)
	return p
}

// fillReleaseDefaults sets ReleasedAt on the MOD's releases when the
// fixture left it blank, since api.Release requires a parseable
// timestamp regardless of whether the test cares about it.
func fillReleaseDefaults(m *portalMOD) {
	const defaultReleasedAt = "2026-01-01T00:00:00Z"
	if m.LatestRelease != nil && m.LatestRelease.ReleasedAt == "" {
		m.LatestRelease.ReleasedAt = defaultReleasedAt
	}
	for i := range m.Releases {
		if m.Releases[i].ReleasedAt == "" {
			m.Releases[i].ReleasedAt = defaultReleasedAt
		}
	}
}

func (p *mockPortal) handle(w http.ResponseWriter, r *http.Request) {
	switch {
	case strings.HasPrefix(r.URL.Path, "/api/mods/") && strings.HasSuffix(r.URL.Path, "/full"):
		name := strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/api/mods/"), "/full")
		p.writeMOD(w, name, true)
	case strings.HasPrefix(r.URL.Path, "/api/mods/"):
		name := strings.TrimPrefix(r.URL.Path, "/api/mods/")
		p.writeMOD(w, name, false)
	case r.URL.Path == "/api/mods":
		p.writeList(w)
	case strings.HasPrefix(r.URL.Path, "/download/"):
		p.downloads = append(p.downloads, r.URL.Path+"?"+r.URL.RawQuery)
		w.Header().Set("Content-Type", "application/octet-stream")
		_, _ = w.Write(p.fileContent)
	case strings.HasPrefix(r.URL.Path, "/api/v2/mods/"):
		p.handleManagement(w, r)
	case r.URL.Path == "/finish-upload":
		p.handleFinishUpload(w, r)
	default:
		http.NotFound(w, r)
	}
}

// handleManagement serves every /api/v2/mods/... endpoint (init_publish,
// releases/init_upload, edit_details, images/add, images/edit): it records
// the call and, for the init_* endpoints, hands back an upload_url pointing
// at this same server's /finish-upload.
func (p *mockPortal) handleManagement(w http.ResponseWriter, r *http.Request) {
	_ = r.ParseForm()
	call := managementCall{Path: r.URL.Path, Auth: r.Header.Get("Authorization"), Form: map[string][]string(r.PostForm)}
	if mod := r.PostForm.Get("mod"); mod != "" {
		call.MODArg = mod
	}
	p.managementCalls = append(p.managementCalls, call)

	w.Header().Set("Content-Type", "application/json")
	switch r.URL.Path {
	case "/api/v2/mods/init_publish", "/api/v2/mods/releases/init_upload", "/api/v2/mods/images/add":
		_ = json.NewEncoder(w).Encode(map[string]string{"upload_url": p.server.URL + "/finish-upload"})
	case "/api/v2/mods/edit_details", "/api/v2/mods/images/edit":
		_ = json.NewEncoder(w).Encode(map[string]bool{"success": true})
	default:
		http.NotFound(w, r)
	}
}

// handleFinishUpload serves the URL init_publish/init_upload/images/add
// point at. It doesn't need to distinguish a MOD-file upload from an image
// upload by content — FinishUpload ignores the response body, and
// FinishImageUpload always decodes an Image, so returning imageUploadResponse
// unconditionally satisfies both.
func (p *mockPortal) handleFinishUpload(w http.ResponseWriter, r *http.Request) {
	_ = r.ParseMultipartForm(32 << 20)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(p.imageUploadResponse)
}

// writeMOD serves a MOD's info. The real Portal's /full endpoint carries
// the full Releases list but never latest_release (confirmed against the
// live API) — it would be redundant, since the caller can derive "latest"
// from Releases itself. Only the short endpoint and the /api/mods list
// endpoint (without namelist) include latest_release.
func (p *mockPortal) writeMOD(w http.ResponseWriter, name string, full bool) {
	m, ok := p.mods[name]
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		_ = json.NewEncoder(w).Encode(map[string]string{"message": "MOD not found"})
		return
	}
	if full {
		m.LatestRelease = nil
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(m)
}

func (p *mockPortal) writeList(w http.ResponseWriter) {
	results := make([]portalMOD, 0, len(p.mods))
	for _, m := range p.mods {
		results = append(results, m)
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"pagination": map[string]int{"count": len(results), "page": 1, "page_count": 1, "page_size": len(results)},
		"results":    results,
	})
}

// withPortal points FACTORIX_MODS_PORTAL_URL at the mock for the duration
// of the test, and makes commands trust its self-signed certificate (real
// download/portal requests are enforced HTTPS-only) and authenticate
// downloads with fake, valid-looking credentials.
func (p *mockPortal) withPortal(t *testing.T) {
	t.Helper()
	t.Setenv("FACTORIX_MODS_PORTAL_URL", p.server.URL)
	t.Setenv("FACTORIO_USERNAME", "test-user")
	t.Setenv("FACTORIO_TOKEN", "test-token")
	t.Setenv("FACTORIO_API_KEY", "test-api-key")

	pool := x509.NewCertPool()
	pool.AddCert(p.server.Certificate())
	original := httpx.TestRootCAs
	httpx.TestRootCAs = pool
	t.Cleanup(func() { httpx.TestRootCAs = original })
}
