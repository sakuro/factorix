package transfer

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/cache"
	"github.com/sakuro/factorix/internal/httpx"
)

type recordingListener struct {
	started  []int64
	progress []int64
	finished int
}

func (l *recordingListener) OnStart(total int64)      { l.started = append(l.started, total) }
func (l *recordingListener) OnProgress(current int64) { l.progress = append(l.progress, current) }
func (l *recordingListener) OnFinish()                { l.finished++ }

func sha1Hex(data string) string {
	sum := sha1.Sum([]byte(data))
	return hex.EncodeToString(sum[:])
}

func newDownloader(t *testing.T, handler http.HandlerFunc) (*Downloader, *httptest.Server) {
	t.Helper()
	server := httptest.NewTLSServer(handler)
	t.Cleanup(server.Close)
	fs, err := cache.NewFileSystem(filepath.Join(t.TempDir(), "download"), cache.FileSystemOptions{})
	require.NoError(t, err)
	client := httpx.NewClient(httpx.Options{Transport: server.Client().Transport})
	return NewDownloader(fs, client, nil), server
}

func TestDownload(t *testing.T) {
	calls := 0
	downloader, server := newDownloader(t, func(w http.ResponseWriter, r *http.Request) {
		calls++
		// The auth query must reach the server but stay out of the cache key.
		assert.Equal(t, "tok", r.URL.Query().Get("token"))
		w.Write([]byte("mod-content"))
	})

	ctx := context.Background()
	listener := &recordingListener{}
	output := filepath.Join(t.TempDir(), "mod.zip")

	err := downloader.Download(ctx, server.URL+"/download/mod?username=alice&token=tok", output,
		DownloadOptions{ExpectedSHA1: sha1Hex("mod-content"), Listener: listener})
	require.NoError(t, err)

	data, err := os.ReadFile(output)
	require.NoError(t, err)
	assert.Equal(t, []byte("mod-content"), data)
	assert.Equal(t, 1, calls)
	require.NotEmpty(t, listener.started)
	assert.Equal(t, int64(11), listener.started[0])
	assert.Equal(t, 1, listener.finished)

	// Second download of the same path (even with different credentials)
	// is served from the cache.
	listener2 := &recordingListener{}
	output2 := filepath.Join(t.TempDir(), "mod2.zip")
	err = downloader.Download(ctx, server.URL+"/download/mod?username=bob&token=other", output2,
		DownloadOptions{Listener: listener2})
	require.NoError(t, err)
	assert.Equal(t, 1, calls, "second download must hit the cache")

	data, err = os.ReadFile(output2)
	require.NoError(t, err)
	assert.Equal(t, []byte("mod-content"), data)
	assert.Equal(t, []int64{11}, listener2.started)
	assert.Equal(t, 1, listener2.finished)
}

func TestDownloadSHA1Mismatch(t *testing.T) {
	downloader, server := newDownloader(t, func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("tampered"))
	})

	err := downloader.Download(context.Background(), server.URL+"/download/mod",
		filepath.Join(t.TempDir(), "mod.zip"),
		DownloadOptions{ExpectedSHA1: sha1Hex("legit")})
	require.ErrorIs(t, err, ErrDigestMismatch)
}

func TestDownloadCorruptedCacheIsInvalidated(t *testing.T) {
	content := "good-content"
	downloader, server := newDownloader(t, func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(content))
	})
	ctx := context.Background()

	// Prime the cache with corrupted content under the download's cache key.
	corrupted := filepath.Join(t.TempDir(), "src")
	require.NoError(t, os.WriteFile(corrupted, []byte("corrupted"), 0o644))
	stored, err := downloader.Cache.Store(ctx, server.URL+"/download/mod", corrupted)
	require.NoError(t, err)
	require.True(t, stored)

	output := filepath.Join(t.TempDir(), "mod.zip")
	err = downloader.Download(ctx, server.URL+"/download/mod", output,
		DownloadOptions{ExpectedSHA1: sha1Hex(content)})
	require.NoError(t, err)

	data, err := os.ReadFile(output)
	require.NoError(t, err)
	assert.Equal(t, []byte(content), data)
}

func TestDownloadHTTPError(t *testing.T) {
	downloader, server := newDownloader(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	})

	err := downloader.Download(context.Background(), server.URL+"/download/missing",
		filepath.Join(t.TempDir(), "mod.zip"), DownloadOptions{})
	var statusErr *httpx.StatusError
	require.ErrorAs(t, err, &statusErr)
	assert.True(t, statusErr.IsNotFound())
}
