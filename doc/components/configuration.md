# Configuration

Factorix configuration is managed via `Dry::Configurable` in the `Factorix` module.

## Configuration File

### Loading Priority

Configuration file is resolved in the following order:

1. `--config-path` CLI option (if specified)
2. `FACTORIX_CONFIG` environment variable (if set)
3. Default path (XDG-compliant):
   - `$XDG_CONFIG_HOME/factorix/config.rb` (if `XDG_CONFIG_HOME` is set)
   - `~/.config/factorix/config.rb` (default)

### File Format (Ruby DSL)

```ruby
Factorix.configure do |config|
  config.log_level = :debug
  config.http.connect_timeout = 10
  config.cache.api.backend = :redis
end
```

## Settings

Location: `lib/factorix.rb`

### General

```ruby
setting :log_level, default: :info
```

### Runtime

```ruby
setting :runtime do
  setting :executable_path, constructor: ->(v) { v ? Pathname(v) : nil }
  setting :user_dir, constructor: ->(v) { v ? Pathname(v) : nil }
  setting :data_dir, constructor: ->(v) { v ? Pathname(v) : nil }
end
```

### HTTP

```ruby
setting :http do
  setting :connect_timeout, default: 5
  setting :read_timeout, default: 30
  setting :write_timeout, default: 30
end
```

### Cache

Each cache type (`download`, `api`, `info_json`) has a `backend` selector and backend-specific nested settings:

```ruby
setting :cache do
  setting :download do
    setting :backend, default: :file_system        # Backend selector
    setting :ttl, default: nil                     # Time-to-live
    setting :file_system do                        # FileSystem-specific
      setting :root, constructor: ->(v) { v ? Pathname(v) : nil }
      setting :max_file_size, default: nil
      setting :compression_threshold, default: nil
    end
    setting :redis do                              # Redis-specific
      setting :url, default: nil
      setting :lock_timeout, default: 30
    end
    setting :s3 do                                 # S3-specific
      setting :bucket, default: nil
      setting :region, default: nil
      setting :lock_timeout, default: 30
    end
  end
  # api and info_json have the same structure
end
```

**Default values by cache type:**

| Setting | `download` | `api` | `info_json` |
|---------|------------|-------|-------------|
| `ttl` | `nil` | `3600` | `nil` |
| `max_file_size` | `nil` | `10MiB` | `nil` |
| `compression_threshold` | `nil` | `0` | `0` |

## Configuration Examples

### Redis Cache Backend

```ruby
Factorix.configure do |config|
  config.cache.api.backend = :redis
  config.cache.api.redis.url = "redis://localhost:6379/0"  # Or use REDIS_URL env
  config.cache.api.redis.lock_timeout = 30
end
```

### S3 Cache Backend

```ruby
Factorix.configure do |config|
  config.cache.download.backend = :s3
  config.cache.download.s3.bucket = "my-cache-bucket"
  config.cache.download.s3.region = "ap-northeast-1"  # Or use AWS_REGION env
  config.cache.download.s3.lock_timeout = 30
end
```

## Related Documentation

- [Container (DI)](container.md)
- [Cache System](cache.md)
