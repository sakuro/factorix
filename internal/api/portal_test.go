package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/httpx"
	"github.com/sakuro/factorix/internal/mod"
)

const sampleMODJSON = `{
	"name": "test-mod",
	"title": "Test MOD",
	"owner": "someone",
	"summary": "A test",
	"downloads_count": 42,
	"category": "content",
	"score": 12.3,
	"thumbnail": "/assets/thumb.png",
	"releases": [
		{
			"download_url": "/download/test-mod/aaa",
			"file_name": "test-mod_1.0.0.zip",
			"info_json": {"factorio_version": "2.0", "dependencies": ["base"]},
			"released_at": "2024-06-01T12:00:00.000000Z",
			"version": "1.0.0",
			"sha1": "da39a3ee5e6b4b0d3255bfef95601890afd80709"
		},
		{
			"download_url": "/download/test-mod/bbb",
			"file_name": "test-mod_2019.11.20.zip",
			"info_json": {"factorio_version": "2.0"},
			"released_at": "2024-06-02T12:00:00.000000Z",
			"version": "2019.11.20",
			"sha1": "da39a3ee5e6b4b0d3255bfef95601890afd80709"
		}
	]
}`

func newPortalAPI(t *testing.T, handler http.HandlerFunc) *MODPortalAPI {
	t.Helper()
	server := httptest.NewTLSServer(handler)
	t.Cleanup(server.Close)
	client := httpx.NewClient(httpx.Options{Transport: server.Client().Transport})
	portalAPI := NewMODPortalAPI(client, nil, nil)
	portalAPI.BaseURL = server.URL
	return portalAPI
}

func TestGetMOD(t *testing.T) {
	var requestedPath string
	portalAPI := newPortalAPI(t, func(w http.ResponseWriter, r *http.Request) {
		requestedPath = r.URL.Path
		w.Write([]byte(sampleMODJSON))
	})

	info, err := portalAPI.GetMOD(context.Background(), "test-mod")
	require.NoError(t, err)

	assert.Equal(t, "/api/mods/test-mod", requestedPath)
	assert.Equal(t, "test-mod", info.Name)
	assert.Equal(t, 42, info.DownloadsCount)
	assert.Equal(t, "https://assets-mod.factorio.com/assets/thumb.png", info.ThumbnailURL())

	// The 2019.11.20 release has version components over 255 and is dropped.
	require.Len(t, info.Releases, 1)
	assert.Equal(t, mod.MODVersion{Major: 1}, info.Releases[0].Version)
	assert.Equal(t, []string{"base"}, info.Releases[0].InfoJSON.Dependencies)
	assert.Equal(t, 2024, info.Releases[0].ReleasedAt.Year())
}

func TestGetMODNotFound(t *testing.T) {
	portalAPI := newPortalAPI(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	})

	_, err := portalAPI.GetMOD(context.Background(), "missing-mod")
	require.ErrorIs(t, err, ErrMODNotOnPortal)
	assert.Contains(t, err.Error(), "missing-mod")
}

func TestGetMODEscapesName(t *testing.T) {
	var requestedURI string
	portalAPI := newPortalAPI(t, func(w http.ResponseWriter, r *http.Request) {
		requestedURI = r.URL.RequestURI()
		w.Write([]byte(sampleMODJSON))
	})

	_, err := portalAPI.GetMODFull(context.Background(), "Mod With Spaces")
	require.NoError(t, err)
	assert.Equal(t, "/api/mods/Mod%20With%20Spaces/full", requestedURI)
}

func TestGetMODs(t *testing.T) {
	var query string
	portalAPI := newPortalAPI(t, func(w http.ResponseWriter, r *http.Request) {
		query = r.URL.RawQuery
		w.Write([]byte(`{"results": [` + sampleMODJSON + `], "pagination": {"count": 1, "page": 1, "page_count": 1, "page_size": 25}}`))
	})

	hide := true
	page, err := portalAPI.GetMODs(context.Background(), GetMODsOptions{
		Namelist:       []string{"zzz", "aaa"},
		HideDeprecated: &hide,
		Page:           2,
		PageSize:       "25",
		Sort:           "updated_at",
		SortOrder:      "desc",
		Version:        "2.0",
	})
	require.NoError(t, err)

	// Query parameters are sorted and the namelist itself is sorted.
	assert.Equal(t, "hide_deprecated=true&namelist=aaa&namelist=zzz&page=2&page_size=25&sort=updated_at&sort_order=desc&version=2.0", query)
	require.Len(t, page.Results, 1)
	assert.Equal(t, 1, page.Pagination.Count)
}

func TestGetMODsValidation(t *testing.T) {
	portalAPI := NewMODPortalAPI(nil, nil, nil)
	ctx := context.Background()

	for _, opts := range []GetMODsOptions{
		{PageSize: "0"},
		{PageSize: "many"},
		{Sort: "downloads"},
		{SortOrder: "up"},
		{Version: "3.0"},
	} {
		_, err := portalAPI.GetMODs(ctx, opts)
		require.ErrorIs(t, err, ErrInvalidArgument, "%+v", opts)
	}

	// "max" is a valid page size but requires a server; validation alone passes.
	require.NoError(t, GetMODsOptions{PageSize: "max"}.validate())
}
