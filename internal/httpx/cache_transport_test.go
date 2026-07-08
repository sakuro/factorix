package httpx

import (
	"bytes"
	"io"
	"net/http"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/cache"
)

// countingTransport serves canned responses and counts upstream calls.
type countingTransport struct {
	calls      int
	statusCode int
	body       string
}

func (c *countingTransport) RoundTrip(*http.Request) (*http.Response, error) {
	c.calls++
	status := c.statusCode
	if status == 0 {
		status = http.StatusOK
	}
	return &http.Response{
		StatusCode: status,
		Header:     http.Header{"Content-Type": []string{"application/json"}},
		Body:       io.NopCloser(bytes.NewReader([]byte(c.body))),
	}, nil
}

func newCacheTransport(t *testing.T, next http.RoundTripper) *CacheTransport {
	t.Helper()
	fs, err := cache.NewFileSystem(filepath.Join(t.TempDir(), "api"), cache.FileSystemOptions{})
	require.NoError(t, err)
	return NewCacheTransport(next, fs, nil)
}

func doGet(t *testing.T, rt http.RoundTripper, url string) []byte {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, url, nil)
	require.NoError(t, err)
	resp, err := rt.RoundTrip(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	return body
}

func TestCacheTransportCachesGET(t *testing.T) {
	next := &countingTransport{body: `{"result": 1}`}
	ct := newCacheTransport(t, next)

	assert.Equal(t, `{"result": 1}`, string(doGet(t, ct, "https://example.com/api")))
	assert.Equal(t, `{"result": 1}`, string(doGet(t, ct, "https://example.com/api")))
	assert.Equal(t, 1, next.calls, "second GET must be served from the cache")

	// A different URL is a different cache entry.
	doGet(t, ct, "https://example.com/api?page=2")
	assert.Equal(t, 2, next.calls)
}

func TestCacheTransportSkipsNonGET(t *testing.T) {
	next := &countingTransport{body: "ok"}
	ct := newCacheTransport(t, next)

	for range 2 {
		req, err := http.NewRequest(http.MethodPost, "https://example.com/api", bytes.NewReader([]byte("body")))
		require.NoError(t, err)
		resp, err := ct.RoundTrip(req)
		require.NoError(t, err)
		resp.Body.Close()
	}
	assert.Equal(t, 2, next.calls)
}

func TestCacheTransportDoesNotCacheErrors(t *testing.T) {
	next := &countingTransport{statusCode: http.StatusInternalServerError, body: "boom"}
	ct := newCacheTransport(t, next)

	for range 2 {
		req, err := http.NewRequest(http.MethodGet, "https://example.com/api", nil)
		require.NoError(t, err)
		resp, err := ct.RoundTrip(req)
		require.NoError(t, err)
		assert.Equal(t, http.StatusInternalServerError, resp.StatusCode)
		resp.Body.Close()
	}
	assert.Equal(t, 2, next.calls)
}
