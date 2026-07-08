package cache

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func durationPtr(d time.Duration) *time.Duration {
	return &d
}

func int64Ptr(v int64) *int64 {
	return &v
}

func newFS(t *testing.T, opts FileSystemOptions) *FileSystem {
	t.Helper()
	c, err := NewFileSystem(filepath.Join(t.TempDir(), "cache"), opts)
	require.NoError(t, err)
	return c
}

func srcFile(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "src")
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))
	return path
}

func TestFileSystemStoreAndRead(t *testing.T) {
	ctx := context.Background()
	c := newFS(t, FileSystemOptions{})

	ok, err := c.Store(ctx, "http://example.com/mod.zip", srcFile(t, "content"))
	require.NoError(t, err)
	require.True(t, ok)

	exists, err := c.Exists(ctx, "http://example.com/mod.zip")
	require.NoError(t, err)
	assert.True(t, exists)

	data, ok, err := c.Read(ctx, "http://example.com/mod.zip")
	require.NoError(t, err)
	require.True(t, ok)
	assert.Equal(t, []byte("content"), data)

	_, ok, err = c.Read(ctx, "other-key")
	require.NoError(t, err)
	assert.False(t, ok)
}

func TestFileSystemCompression(t *testing.T) {
	ctx := context.Background()
	c := newFS(t, FileSystemOptions{CompressionThreshold: int64Ptr(0)})

	content := "compress me compress me compress me"
	ok, err := c.Store(ctx, "key", srcFile(t, content))
	require.NoError(t, err)
	require.True(t, ok)

	// On disk the data carries a zlib header; Read is transparent.
	raw, err := os.ReadFile(c.dataPath("key"))
	require.NoError(t, err)
	assert.True(t, zlibCompressed(raw))

	data, ok, err := c.Read(ctx, "key")
	require.NoError(t, err)
	require.True(t, ok)
	assert.Equal(t, []byte(content), data)
}

func TestFileSystemCompressionThresholdNotMet(t *testing.T) {
	ctx := context.Background()
	c := newFS(t, FileSystemOptions{CompressionThreshold: int64Ptr(1024)})

	ok, err := c.Store(ctx, "key", srcFile(t, "small"))
	require.NoError(t, err)
	require.True(t, ok)

	raw, err := os.ReadFile(c.dataPath("key"))
	require.NoError(t, err)
	assert.Equal(t, []byte("small"), raw)
}

func TestFileSystemMaxFileSize(t *testing.T) {
	ctx := context.Background()
	c := newFS(t, FileSystemOptions{MaxFileSize: int64Ptr(3)})

	ok, err := c.Store(ctx, "key", srcFile(t, "too large"))
	require.NoError(t, err)
	assert.False(t, ok)

	exists, err := c.Exists(ctx, "key")
	require.NoError(t, err)
	assert.False(t, exists)
}

func TestFileSystemTTL(t *testing.T) {
	ctx := context.Background()
	c := newFS(t, FileSystemOptions{TTL: durationPtr(time.Hour)})

	ok, err := c.Store(ctx, "key", srcFile(t, "content"))
	require.NoError(t, err)
	require.True(t, ok)

	exists, err := c.Exists(ctx, "key")
	require.NoError(t, err)
	assert.True(t, exists)

	// Age the entry beyond the TTL.
	past := time.Now().Add(-2 * time.Hour)
	require.NoError(t, os.Chtimes(c.dataPath("key"), past, past))

	exists, err = c.Exists(ctx, "key")
	require.NoError(t, err)
	assert.False(t, exists)

	_, ok, err = c.Read(ctx, "key")
	require.NoError(t, err)
	assert.False(t, ok)
}

func TestFileSystemWriteTo(t *testing.T) {
	ctx := context.Background()
	c := newFS(t, FileSystemOptions{})

	ok, err := c.Store(ctx, "key", srcFile(t, "content"))
	require.NoError(t, err)
	require.True(t, ok)

	output := filepath.Join(t.TempDir(), "out")
	ok, err = c.WriteTo(ctx, "key", output)
	require.NoError(t, err)
	require.True(t, ok)

	data, err := os.ReadFile(output)
	require.NoError(t, err)
	assert.Equal(t, []byte("content"), data)

	ok, err = c.WriteTo(ctx, "missing", filepath.Join(t.TempDir(), "out2"))
	require.NoError(t, err)
	assert.False(t, ok)
}

func TestFileSystemDeleteAndClear(t *testing.T) {
	ctx := context.Background()
	c := newFS(t, FileSystemOptions{})

	for _, key := range []string{"a", "b"} {
		ok, err := c.Store(ctx, key, srcFile(t, key))
		require.NoError(t, err)
		require.True(t, ok)
	}

	ok, err := c.Delete(ctx, "a")
	require.NoError(t, err)
	assert.True(t, ok)
	ok, err = c.Delete(ctx, "a")
	require.NoError(t, err)
	assert.False(t, ok)

	require.NoError(t, c.Clear(ctx))
	entries, err := c.Entries(ctx)
	require.NoError(t, err)
	assert.Empty(t, entries)
}

func TestFileSystemEntries(t *testing.T) {
	ctx := context.Background()
	c := newFS(t, FileSystemOptions{})

	ok, err := c.Store(ctx, "logical-key-1", srcFile(t, "data1"))
	require.NoError(t, err)
	require.True(t, ok)

	entries, err := c.Entries(ctx)
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.Equal(t, "logical-key-1", entries[0].Key)
	assert.Equal(t, int64(5), entries[0].Size)
	assert.False(t, entries[0].Expired)
}

func TestFileSystemWithLock(t *testing.T) {
	ctx := context.Background()
	c := newFS(t, FileSystemOptions{})

	ran := false
	err := c.WithLock(ctx, "key", func() error {
		ran = true
		// The lock file exists while the lock is held.
		_, statErr := os.Stat(c.lockPath("key"))
		assert.NoError(t, statErr)
		return nil
	})
	require.NoError(t, err)
	assert.True(t, ran)

	// The lock file is removed after release.
	_, err = os.Stat(c.lockPath("key"))
	assert.ErrorIs(t, err, os.ErrNotExist)
}

func TestFileSystemStaleLockCleanup(t *testing.T) {
	ctx := context.Background()
	c := newFS(t, FileSystemOptions{})

	lockPath := c.lockPath("key")
	require.NoError(t, os.MkdirAll(filepath.Dir(lockPath), 0o755))
	require.NoError(t, os.WriteFile(lockPath, nil, 0o644))
	past := time.Now().Add(-2 * lockFileLifetime)
	require.NoError(t, os.Chtimes(lockPath, past, past))

	assert.Equal(t, 1, c.Info().StaleLocks)

	// A stale lock does not block acquisition.
	err := c.WithLock(ctx, "key", func() error { return nil })
	require.NoError(t, err)
	assert.Equal(t, 0, c.Info().StaleLocks)
}

func TestFileSystemInfo(t *testing.T) {
	c := newFS(t, FileSystemOptions{MaxFileSize: int64Ptr(100), CompressionThreshold: int64Ptr(10)})
	info := c.Info()
	assert.Equal(t, "file_system", info.Type)
	assert.Equal(t, c.dir, info.Directory)
	assert.Equal(t, int64(100), *info.MaxFileSize)
	assert.Equal(t, int64(10), *info.CompressionThreshold)
}
