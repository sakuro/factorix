// Package transfer downloads and uploads files with caching and progress
// reporting.
package transfer

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"io"
	"log/slog"
	"net/url"
	"os"
	"path/filepath"

	"github.com/sakuro/factorix/internal/cache"
	"github.com/sakuro/factorix/internal/httpx"
	"github.com/sakuro/factorix/internal/progress"
)

// Downloader downloads files with caching. Concurrent downloads of the same
// URL are serialized by the cache lock, so only one process fetches while
// the others wait and then hit the cache.
type Downloader struct {
	Cache  cache.Cache
	Client *httpx.Client // retry only; caching is handled here, not by CacheTransport
	Logger *slog.Logger
}

// NewDownloader builds a downloader.
func NewDownloader(c cache.Cache, client *httpx.Client, logger *slog.Logger) *Downloader {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &Downloader{Cache: c, Client: client, Logger: logger}
}

// DownloadOptions modify a download.
type DownloadOptions struct {
	// ExpectedSHA1 enables digest verification of both cached and freshly
	// downloaded content.
	ExpectedSHA1 string
	Listener     progress.Listener
}

// Download fetches rawURL to the output path, serving from the cache when
// possible. A cached file failing SHA1 verification is invalidated and
// re-downloaded.
func (d *Downloader) Download(ctx context.Context, rawURL, output string, opts DownloadOptions) error {
	cacheKey, err := stripQuery(rawURL)
	if err != nil {
		return err
	}
	d.Logger.Info("Starting download", "output", output)

	hit, err := d.tryCacheHit(ctx, cacheKey, output, opts)
	if err != nil {
		return err
	}
	if hit {
		return nil
	}
	d.Logger.Debug("Cache miss, downloading", "output", output)

	return d.Cache.WithLock(ctx, cacheKey, func() error {
		// Another process may have completed the download while we waited.
		hit, err := d.tryCacheHit(ctx, cacheKey, output, opts)
		if err != nil || hit {
			return err
		}

		tempDir, err := os.MkdirTemp("", "factorix-download")
		if err != nil {
			return err
		}
		defer os.RemoveAll(tempDir)
		tempFile := filepath.Join(tempDir, "download")

		if err := d.downloadWithProgress(ctx, rawURL, tempFile, opts.Listener); err != nil {
			return err
		}
		if opts.ExpectedSHA1 != "" {
			if err := verifySHA1(tempFile, opts.ExpectedSHA1); err != nil {
				return err
			}
		}
		if _, err := d.Cache.Store(ctx, cacheKey, tempFile); err != nil {
			return err
		}
		// Copy from the temp file, not the cache, so a store skipped by a
		// size limit still produces the output.
		return copyFile(tempFile, output)
	})
}

// tryCacheHit writes cached content to output. On a SHA1 mismatch the entry
// is invalidated and (false, nil) is returned to trigger a re-download.
func (d *Downloader) tryCacheHit(ctx context.Context, cacheKey, output string, opts DownloadOptions) (bool, error) {
	found, err := d.Cache.WriteTo(ctx, cacheKey, output)
	if err != nil || !found {
		return false, err
	}
	d.Logger.Info("Cache hit", "output", output)

	if opts.ExpectedSHA1 != "" {
		if err := verifySHA1(output, opts.ExpectedSHA1); err != nil {
			d.Logger.Warn("Cache corrupted, invalidating", "output", output, "error", err)
			if _, deleteErr := d.Cache.Delete(ctx, cacheKey); deleteErr != nil {
				return false, deleteErr
			}
			return false, nil
		}
	}

	if info, err := os.Stat(output); err == nil {
		progress.Start(opts.Listener, info.Size())
		progress.Update(opts.Listener, info.Size())
		progress.Finish(opts.Listener)
	}
	return true, nil
}

func (d *Downloader) downloadWithProgress(ctx context.Context, rawURL, output string, listener progress.Listener) error {
	resp, err := d.Client.GetStream(ctx, rawURL)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	progress.Start(listener, resp.ContentLength) // -1 when unknown

	file, err := os.Create(output)
	if err != nil {
		return err
	}
	defer file.Close()

	counter := &countingWriter{listener: listener}
	if _, err := io.Copy(io.MultiWriter(file, counter), resp.Body); err != nil {
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	progress.Finish(listener)
	return nil
}

// countingWriter forwards the cumulative byte count to the listener.
type countingWriter struct {
	listener progress.Listener
	current  int64
}

func (w *countingWriter) Write(p []byte) (int, error) {
	w.current += int64(len(p))
	progress.Update(w.listener, w.current)
	return len(p), nil
}

func verifySHA1(path, expected string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()

	h := sha1.New()
	if _, err := io.Copy(h, f); err != nil {
		return err
	}
	actual := hex.EncodeToString(h.Sum(nil))
	if actual != expected {
		return fmt.Errorf("%w: expected %s, got %s", ErrDigestMismatch, expected, actual)
	}
	return nil
}

// stripQuery removes the query from the URL so credentials (username/token)
// never end up in cache keys or metadata.
func stripQuery(rawURL string) (string, error) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return "", err
	}
	u.RawQuery = ""
	return u.String(), nil
}

func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0o644)
}
