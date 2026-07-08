// Package cache provides content caching behind a backend-neutral interface.
// Only the filesystem backend is implemented; the Ruby Redis and S3 backends
// are intentionally out of scope.
package cache

import (
	"context"
	"time"
)

// Entry describes one cache entry for enumeration.
type Entry struct {
	Key     string
	Size    int64
	Age     time.Duration
	Expired bool
}

// BackendInfo describes a backend's configuration and status.
type BackendInfo struct {
	Type                 string
	Directory            string
	MaxFileSize          *int64
	CompressionThreshold *int64
	StaleLocks           int
}

// Cache stores content under logical string keys.
type Cache interface {
	// Exists reports whether a non-expired entry exists.
	Exists(ctx context.Context, key string) (bool, error)
	// Read returns the entry content; ok is false on a miss or expiry.
	Read(ctx context.Context, key string) (data []byte, ok bool, err error)
	// WriteTo writes the entry content to outputPath; found is false on a miss.
	WriteTo(ctx context.Context, key, outputPath string) (found bool, err error)
	// Store caches the file at srcPath; stored is false when the entry was
	// skipped (e.g. size limit).
	Store(ctx context.Context, key, srcPath string) (stored bool, err error)
	// Delete removes an entry. The end state is the same either way;
	// deleted reports whether this call actually removed it.
	Delete(ctx context.Context, key string) (deleted bool, err error)
	// Clear removes all entries.
	Clear(ctx context.Context) error
	// WithLock runs fn while holding an exclusive cross-process lock on key.
	WithLock(ctx context.Context, key string, fn func() error) error
	// Entries lists all entries.
	Entries(ctx context.Context) ([]Entry, error)
	// Info returns backend configuration and status.
	Info() BackendInfo
}
