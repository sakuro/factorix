# Cache System

File-system based caching infrastructure for MOD files, API responses, and metadata.

## Overview

Factorix uses three specialized cache instances optimized for different data types:

| Cache | Purpose | TTL | Compression |
|-------|---------|-----|-------------|
| `download_cache` | MOD files (.zip) | Unlimited | Disabled |
| `api_cache` | API JSON responses | 3600s (1 hour) | Always |
| `info_json_cache` | MOD metadata (info.json) | Unlimited | Always |

**Design rationale:**
- MOD files are immutable (version-specific), so unlimited TTL is safe
- API responses may change (new releases, metadata updates), so TTL expiration is required
- info.json is extracted from immutable MOD archives, so unlimited TTL is safe
- Compression is disabled for binary MOD files (already compressed), enabled for JSON (high compression ratio)

## Architecture

```mermaid
graph TD
    subgraph "HTTP Layer"
        API[API Clients] --> CacheDecorator
        CacheDecorator --> RetryDecorator
        RetryDecorator --> Client[HTTP::Client]
    end

    subgraph "Cache Layer"
        CacheDecorator --> FileSystem[Cache::FileSystem]
        FileSystem --> Storage[(File Storage)]
    end

    subgraph "Transfer Layer"
        Downloader --> FileSystem
    end

    CacheDecorator -.-> CachedResponse
```

### Components

| Class | Responsibility |
|-------|----------------|
| `Cache::FileSystem` | Core caching with file storage, compression, locking |
| `HTTP::CacheDecorator` | HTTP response caching (decorator pattern) |
| `HTTP::CachedResponse` | Cached response wrapper |

## FileSystem Class

Location: `lib/factorix/cache/file_system.rb`

### Public API

| Method | Description |
|--------|-------------|
| `key_for(url_string)` | Generate SHA1 cache key from URL |
| `exist?(key)` | Check if entry exists and is not expired |
| `fetch(key, output)` | Copy cached file to output path |
| `read(key, encoding)` | Read cached content as string |
| `store(key, src)` | Store file in cache |
| `delete(key)` | Delete specific entry |
| `clear()` | Clear all entries |
| `age(key)` | Get entry age in seconds |
| `expired?(key)` | Check if entry exceeded TTL |
| `size(key)` | Get cached file size |
| `with_lock(key)` | Execute block with exclusive file lock |

### Storage Format

Two-level directory structure to prevent filesystem overload:

```
cache_dir/
├── ab/
│   └── cdef1234567890...  # Full key after first 2 chars
├── 12/
│   └── 3456789abcdef0...
└── ...
```

### Key Generation

Cache keys are generated using SHA1 hash of the full URL:

```ruby
key = cache.key_for("https://mods.factorio.com/api/mods/example")
# => "a1b2c3d4e5f6..."
```

### Compression

Controlled by `compression_threshold` parameter:

| Value | Behavior |
|-------|----------|
| `nil` | No compression |
| `0` | Always compress |
| `N` | Compress if size >= N bytes |

- Uses zlib compression
- Auto-detects compression on read via CMF byte validation (`0x78`)
- Transparent to callers (compression/decompression is automatic)

### File Locking

- Uses `flock()` for process-safe exclusive locking
- Prevents concurrent downloads of same resource
- Stale lock cleanup: removes locks older than 3600 seconds
- Double-check pattern in CacheDecorator ensures cache consistency

## HTTP Cache Decorator

Location: `lib/factorix/http/cache_decorator.rb`

### Caching Rules

- **Cached**: Non-streaming GET requests (no block)
- **Not cached**: Streaming requests (with block), POST, PUT, DELETE

### Caching Flow

1. Check if cached copy exists
2. If hit: return `CachedResponse`, publish `cache.hit` event
3. If miss: acquire exclusive lock on cache key
4. Double-check cache (another process may have filled it)
5. Execute HTTP request
6. If successful (2xx): store response body via temporary file
7. Publish `cache.miss` event
8. Return response

### Event Publishing

| Event | Payload | Description |
|-------|---------|-------------|
| `cache.hit` | `{uri:}` | Cache hit occurred |
| `cache.miss` | `{uri:}` | Cache miss, request executed |

## Event-Driven Cache Invalidation

When MOD metadata changes on the portal, cached data must be invalidated.

### Event Flow

```mermaid
sequenceDiagram
    participant User
    participant MODManagementAPI
    participant MODPortalAPI
    participant Cache

    User->>MODManagementAPI: upload/edit MOD
    MODManagementAPI->>MODManagementAPI: publish mod.changed event
    MODManagementAPI-->>MODPortalAPI: event notification
    MODPortalAPI->>Cache: invalidate MOD cache entries
```

### Trigger Operations

`MODManagementAPI` publishes `mod.changed` event after:
- `finish_upload()` - MOD published or updated
- `edit_details()` - Metadata edited
- `finish_image_upload()` - Image added
- `edit_images()` - Image list modified

### Invalidation Logic

`MODPortalAPI` subscribes and invalidates both endpoints:
- `/api/mods/{mod_name}` - Basic MOD info
- `/api/mods/{mod_name}/full` - Full MOD info with releases

## Configuration

Location: `lib/factorix/application.rb`

### Cache Settings

```ruby
setting :cache do
  setting :download do
    setting :dir, constructor: ->(v) { Pathname(v) }
    setting :ttl, default: nil                      # Unlimited
    setting :max_file_size, default: nil            # Unlimited
    setting :compression_threshold, default: nil    # No compression
  end

  setting :api do
    setting :dir, constructor: ->(v) { Pathname(v) }
    setting :ttl, default: 3600                     # 1 hour
    setting :max_file_size, default: 10 * 1024 * 1024  # 10MiB
    setting :compression_threshold, default: 0      # Always compress
  end

  setting :info_json do
    setting :dir, constructor: ->(v) { Pathname(v) }
    setting :ttl, default: nil                      # Unlimited
    setting :max_file_size, default: nil            # Unlimited
    setting :compression_threshold, default: 0      # Always compress
  end
end
```

### DI Container Registration

```ruby
register(:download_cache, memoize: true) do
  c = config.cache.download
  Cache::FileSystem.new(c.dir, **c.to_h.except(:dir))
end

register(:api_cache, memoize: true) do
  c = config.cache.api
  Cache::FileSystem.new(c.dir, **c.to_h.except(:dir))
end

register(:info_json_cache, memoize: true) do
  c = config.cache.info_json
  Cache::FileSystem.new(c.dir, **c.to_h.except(:dir))
end
```

## CLI Commands

See [`cli.md`](cli.md) for cache management commands:
- `factorix cache stat` - Display cache statistics
- `factorix cache evict` - Remove cache entries

## Related Documentation

- [`cli.md`](cli.md) - Cache CLI commands
- [`http.md`](http.md) - HTTP decorator chain
- [`runtime.md`](runtime.md) - Cache directory paths (`xdg_cache_home_dir`)
- [`api-portal.md`](api-portal.md) - Cache key optimization for API calls
