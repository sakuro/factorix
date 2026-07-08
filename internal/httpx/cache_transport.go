package httpx

import (
	"bytes"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strconv"

	"github.com/sakuro/factorix/internal/cache"
)

// CacheTransport implements cache-aside for GET requests: hits are served
// from the cache without touching the network; misses go through next and
// successful responses are stored. Other methods pass through untouched.
type CacheTransport struct {
	next   http.RoundTripper
	cache  cache.Cache
	logger *slog.Logger
}

// NewCacheTransport wraps next with response caching.
func NewCacheTransport(next http.RoundTripper, c cache.Cache, logger *slog.Logger) *CacheTransport {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &CacheTransport{next: next, cache: c, logger: logger}
}

// RoundTrip implements http.RoundTripper.
func (t *CacheTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	if req.Method != http.MethodGet {
		return t.next.RoundTrip(req)
	}

	ctx := req.Context()
	key := req.URL.String()

	if data, ok, err := t.cache.Read(ctx, key); err != nil {
		return nil, err
	} else if ok {
		t.logger.Debug("Cache hit", "url", key)
		return cachedResponse(req, data), nil
	}
	t.logger.Debug("Cache miss", "url", key)

	var resp *http.Response
	// Locking prevents concurrent downloads of the same resource.
	err := t.cache.WithLock(ctx, key, func() error {
		// Double-check: another process may have filled the cache.
		if data, ok, err := t.cache.Read(ctx, key); err != nil {
			return err
		} else if ok {
			resp = cachedResponse(req, data)
			return nil
		}

		upstream, err := t.next.RoundTrip(req)
		if err != nil {
			return err
		}
		if upstream.StatusCode < 200 || upstream.StatusCode >= 300 {
			resp = upstream
			return nil
		}

		body, err := io.ReadAll(upstream.Body)
		upstream.Body.Close()
		if err != nil {
			return err
		}
		if err := t.store(req, key, body); err != nil {
			return err
		}
		upstream.Body = io.NopCloser(bytes.NewReader(body))
		resp = upstream
		return nil
	})
	if err != nil {
		return nil, err
	}
	return resp, nil
}

// store passes the body through a temporary file because the Cache interface
// stores from file paths (the download path streams large files).
func (t *CacheTransport) store(req *http.Request, key string, body []byte) error {
	tmp, err := os.CreateTemp("", "factorix-http-cache")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(body); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	_, err = t.cache.Store(req.Context(), key, tmp.Name())
	return err
}

// cachedResponse synthesizes an http.Response from cached content. The
// original headers are not stored, so the content type is generic.
func cachedResponse(req *http.Request, data []byte) *http.Response {
	return &http.Response{
		Status:     "200 OK",
		StatusCode: http.StatusOK,
		Proto:      "HTTP/1.1",
		ProtoMajor: 1,
		ProtoMinor: 1,
		Header: http.Header{
			"Content-Type":   []string{"application/octet-stream"},
			"Content-Length": []string{strconv.Itoa(len(data))},
		},
		ContentLength: int64(len(data)),
		Body:          io.NopCloser(bytes.NewReader(data)),
		Request:       req,
	}
}
