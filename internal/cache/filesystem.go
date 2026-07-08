package cache

import (
	"bytes"
	"compress/zlib"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gofrs/flock"
)

// Lock files older than this are considered stale and removed.
const lockFileLifetime = time.Hour

const lockRetryInterval = 100 * time.Millisecond

// zlib CMF byte indicating DEFLATE compression with the default window size.
const zlibCMFByte = 0x78

// FileSystem is a filesystem cache. Each entry is a data file (optionally
// zlib-compressed) named by the SHA-256 of the logical key in a two-level
// directory layout, plus a .metadata sidecar recording the logical key and
// a .lock file for cross-process locking.
type FileSystem struct {
	dir                  string
	ttl                  *time.Duration
	maxFileSize          *int64
	compressionThreshold *int64
	logger               *slog.Logger
}

// FileSystemOptions configures a FileSystem cache. Nil values mean:
// TTL — never expire; MaxFileSize — unlimited; CompressionThreshold — never
// compress (0 compresses everything, N compresses entries of N bytes or more).
type FileSystemOptions struct {
	TTL                  *time.Duration
	MaxFileSize          *int64
	CompressionThreshold *int64
	Logger               *slog.Logger
}

// NewFileSystem creates the cache directory and returns the cache.
func NewFileSystem(dir string, opts FileSystemOptions) (*FileSystem, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	logger := opts.Logger
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &FileSystem{
		dir:                  dir,
		ttl:                  opts.TTL,
		maxFileSize:          opts.MaxFileSize,
		compressionThreshold: opts.CompressionThreshold,
		logger:               logger,
	}, nil
}

func (c *FileSystem) dataPath(key string) string {
	sum := sha256.Sum256([]byte(key))
	storageKey := hex.EncodeToString(sum[:])
	return filepath.Join(c.dir, storageKey[:2], storageKey[2:])
}

func (c *FileSystem) metadataPath(key string) string {
	return c.dataPath(key) + ".metadata"
}

func (c *FileSystem) lockPath(key string) string {
	return c.dataPath(key) + ".lock"
}

func (c *FileSystem) expired(path string) bool {
	if c.ttl == nil {
		return false
	}
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return time.Since(info.ModTime()) > *c.ttl
}

// Exists reports whether a non-expired entry exists.
func (c *FileSystem) Exists(ctx context.Context, key string) (bool, error) {
	if err := ctx.Err(); err != nil {
		return false, err
	}
	path := c.dataPath(key)
	if _, err := os.Stat(path); err != nil {
		return false, nil
	}
	return !c.expired(path), nil
}

// Read returns the entry content, transparently decompressing zlib data.
func (c *FileSystem) Read(ctx context.Context, key string) ([]byte, bool, error) {
	if err := ctx.Err(); err != nil {
		return nil, false, err
	}
	path := c.dataPath(key)
	data, err := os.ReadFile(path)
	if err != nil {
		c.logger.Debug("Cache miss", "key", key)
		return nil, false, nil
	}
	if c.expired(path) {
		c.logger.Debug("Cache expired", "key", key)
		return nil, false, nil
	}
	if zlibCompressed(data) {
		data, err = inflate(data)
		if err != nil {
			return nil, false, err
		}
	}
	c.logger.Debug("Cache hit", "key", key)
	return data, true, nil
}

// WriteTo writes the entry content to outputPath.
func (c *FileSystem) WriteTo(ctx context.Context, key, outputPath string) (bool, error) {
	data, ok, err := c.Read(ctx, key)
	if err != nil || !ok {
		return false, err
	}
	if err := os.WriteFile(outputPath, data, 0o644); err != nil {
		return false, err
	}
	return true, nil
}

// Store caches the file at srcPath, compressing per the threshold. Entries
// whose (possibly compressed) size exceeds MaxFileSize are skipped.
func (c *FileSystem) Store(ctx context.Context, key, srcPath string) (bool, error) {
	if err := ctx.Err(); err != nil {
		return false, err
	}
	data, err := os.ReadFile(srcPath)
	if err != nil {
		return false, err
	}

	if c.compressionThreshold != nil && int64(len(data)) >= *c.compressionThreshold {
		compressed, err := deflate(data)
		if err != nil {
			return false, err
		}
		c.logger.Debug("Compressed data", "original_size", len(data), "compressed_size", len(compressed))
		data = compressed
	}

	if c.maxFileSize != nil && int64(len(data)) > *c.maxFileSize {
		c.logger.Warn("File size exceeds cache limit, skipping", "size_bytes", len(data), "limit_bytes", *c.maxFileSize)
		return false, nil
	}

	path := c.dataPath(key)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return false, err
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return false, err
	}
	metadata, err := json.Marshal(map[string]string{"logical_key": key})
	if err != nil {
		return false, err
	}
	if err := os.WriteFile(c.metadataPath(key), metadata, 0o644); err != nil {
		return false, err
	}
	c.logger.Debug("Stored in cache", "key", key, "size_bytes", len(data))
	return true, nil
}

// Delete removes an entry and its metadata.
func (c *FileSystem) Delete(ctx context.Context, key string) (bool, error) {
	if err := ctx.Err(); err != nil {
		return false, err
	}
	path := c.dataPath(key)
	if _, err := os.Stat(path); err != nil {
		return false, nil
	}
	if err := os.Remove(path); err != nil {
		return false, err
	}
	_ = os.Remove(c.metadataPath(key))
	c.logger.Debug("Deleted from cache", "key", key)
	return true, nil
}

// Clear removes all entries, leaving lock files in place.
func (c *FileSystem) Clear(ctx context.Context) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	c.logger.Info("Clearing cache directory", "root", c.dir)
	count := 0
	err := filepath.WalkDir(c.dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || strings.HasSuffix(path, ".lock") {
			return err
		}
		if err := os.Remove(path); err != nil {
			return err
		}
		count++
		return nil
	})
	if err != nil {
		return err
	}
	c.logger.Info("Cache cleared", "files_removed", count)
	return nil
}

// WithLock runs fn while holding an exclusive cross-process flock on the
// key's lock file. A stale lock file (older than an hour) is removed first
// so leftovers cannot block the cache indefinitely.
func (c *FileSystem) WithLock(ctx context.Context, key string, fn func() error) error {
	lockPath := c.lockPath(key)
	c.cleanupStaleLock(lockPath)

	if err := os.MkdirAll(filepath.Dir(lockPath), 0o755); err != nil {
		return err
	}
	lock := flock.New(lockPath)
	ok, err := lock.TryLockContext(ctx, lockRetryInterval)
	if err != nil {
		return err
	}
	if !ok {
		return ctx.Err()
	}
	c.logger.Debug("Acquired lock", "key", key)
	defer func() {
		_ = lock.Unlock()
		_ = os.Remove(lockPath)
		c.logger.Debug("Released lock", "key", key)
	}()
	return fn()
}

// Entries lists all entries. Data files without a metadata sidecar are
// skipped: the logical key cannot be recovered from the hash.
func (c *FileSystem) Entries(ctx context.Context) ([]Entry, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	var entries []Entry
	err := filepath.WalkDir(c.dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		if strings.HasSuffix(path, ".metadata") || strings.HasSuffix(path, ".lock") {
			return nil
		}
		metadata, err := os.ReadFile(path + ".metadata")
		if err != nil {
			return nil
		}
		var meta struct {
			LogicalKey string `json:"logical_key"`
		}
		if err := json.Unmarshal(metadata, &meta); err != nil {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return nil
		}
		age := time.Since(info.ModTime())
		entries = append(entries, Entry{
			Key:     meta.LogicalKey,
			Size:    info.Size(),
			Age:     age,
			Expired: c.ttl != nil && age > *c.ttl,
		})
		return nil
	})
	return entries, err
}

// Info returns backend configuration and status.
func (c *FileSystem) Info() BackendInfo {
	return BackendInfo{
		Type:                 "file_system",
		Directory:            c.dir,
		MaxFileSize:          c.maxFileSize,
		CompressionThreshold: c.compressionThreshold,
		StaleLocks:           c.countStaleLocks(),
	}
}

func (c *FileSystem) cleanupStaleLock(lockPath string) {
	info, err := os.Stat(lockPath)
	if err != nil {
		return
	}
	age := time.Since(info.ModTime())
	if age <= lockFileLifetime {
		return
	}
	if err := os.Remove(lockPath); err != nil {
		c.logger.Debug("Failed to remove stale lock", "path", lockPath, "error", err)
		return
	}
	c.logger.Warn("Removed stale lock", "path", lockPath, "age", age)
}

func (c *FileSystem) countStaleLocks() int {
	count := 0
	_ = filepath.WalkDir(c.dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".lock") {
			return err
		}
		info, err := d.Info()
		if err == nil && time.Since(info.ModTime()) > lockFileLifetime {
			count++
		}
		return nil
	})
	return count
}

// zlibCompressed checks the zlib header: CMF 0x78 and a valid FCHECK
// ((CMF<<8 | FLG) divisible by 31).
func zlibCompressed(data []byte) bool {
	if len(data) < 2 {
		return false
	}
	return data[0] == zlibCMFByte && (uint16(data[0])<<8|uint16(data[1]))%31 == 0
}

func deflate(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	w := zlib.NewWriter(&buf)
	if _, err := w.Write(data); err != nil {
		return nil, err
	}
	if err := w.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func inflate(data []byte) ([]byte, error) {
	r, err := zlib.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	defer r.Close()
	return io.ReadAll(r)
}
