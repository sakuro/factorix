package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/httpx"
)

func newGameAPI(t *testing.T, handler http.HandlerFunc) *GameDownloadAPI {
	t.Helper()
	server := httptest.NewTLSServer(handler)
	t.Cleanup(server.Close)
	client := httpx.NewClient(httpx.Options{Transport: server.Client().Transport})
	gameAPI := NewGameDownloadAPI(client, testCredentials(), nil)
	gameAPI.APIBaseURL = server.URL
	gameAPI.DownloadBaseURL = server.URL
	return gameAPI
}

func TestLatestVersion(t *testing.T) {
	gameAPI := newGameAPI(t, func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/api/latest-releases", r.URL.Path)
		w.Write([]byte(`{
			"stable": {"alpha": "2.0.28", "expansion": "2.0.28", "headless": "2.0.28"},
			"experimental": {"alpha": "2.0.30"}
		}`))
	})

	version, err := gameAPI.LatestVersion(context.Background(), "stable", "expansion")
	require.NoError(t, err)
	assert.Equal(t, "2.0.28", version)

	version, err = gameAPI.LatestVersion(context.Background(), "experimental", "alpha")
	require.NoError(t, err)
	assert.Equal(t, "2.0.30", version)

	// Unavailable build yields "".
	version, err = gameAPI.LatestVersion(context.Background(), "experimental", "demo")
	require.NoError(t, err)
	assert.Empty(t, version)
}

func TestLatestVersionValidation(t *testing.T) {
	gameAPI := NewGameDownloadAPI(nil, testCredentials(), nil)
	ctx := context.Background()

	_, err := gameAPI.LatestVersion(ctx, "nightly", "alpha")
	require.ErrorIs(t, err, ErrInvalidArgument)
	_, err = gameAPI.LatestVersion(ctx, "stable", "beta")
	require.ErrorIs(t, err, ErrInvalidArgument)
}

func TestResolveFilename(t *testing.T) {
	gameAPI := newGameAPI(t, func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/dl/factorio_linux64_2.0.28.tar.xz" {
			w.WriteHeader(http.StatusOK)
			return
		}
		assert.Equal(t, "alice", r.URL.Query().Get("username"))
		assert.Equal(t, "tok", r.URL.Query().Get("token"))
		http.Redirect(w, r, "/dl/factorio_linux64_2.0.28.tar.xz", http.StatusFound)
	})

	filename, err := gameAPI.ResolveFilename(context.Background(), "2.0.28", "alpha", "linux64")
	require.NoError(t, err)
	assert.Equal(t, "factorio_linux64_2.0.28.tar.xz", filename)
}

func TestGameDownloadURL(t *testing.T) {
	gameAPI := NewGameDownloadAPI(nil, testCredentials(), nil)

	downloadURL, err := gameAPI.DownloadURL("2.0.28", "headless", "linux64")
	require.NoError(t, err)
	assert.Equal(t, "https://www.factorio.com/get-download/2.0.28/headless/linux64?token=tok&username=alice", downloadURL)

	_, err = gameAPI.DownloadURL("2.0.28", "bogus", "linux64")
	require.ErrorIs(t, err, ErrInvalidArgument)
}
