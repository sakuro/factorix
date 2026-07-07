# Configuration

Factorix configuration is an immutable `Factorix::Config` value object
(`lib/factorix/config.rb`), built from defaults merged with a TOML file.
`Factorix.config` returns the current configuration.

## Configuration File

### Loading Priority

Configuration file is resolved in the following order:

1. `--config-path` CLI option (if specified)
2. `FACTORIX_CONFIG` environment variable (if set)
3. Default path (XDG-compliant):
   - `$XDG_CONFIG_HOME/factorix/config.toml` (if `XDG_CONFIG_HOME` is set)
   - `~/.config/factorix/config.toml` (default)

### File Format (TOML)

```toml
log_level = "debug"

[http]
connect_timeout = 10

[cache.api]
backend = "redis"
```

Unknown keys are rejected with a `ConfigurationError`.

### Migration from the Ruby DSL

Versions before the TOML switch used an `instance_eval`'d Ruby DSL at
`config.rb`. When a legacy `config.rb` is found (at the default location, or
given explicitly), Factorix converts it and aborts with the equivalent TOML so
the user can review and save it as `config.toml`.

## Settings

Location: `lib/factorix/config.rb` (`DEFAULTS`)

| Key | Default | Notes |
|-----|---------|-------|
| `log_level` | `"info"` | debug / info / warn / error / fatal |
| `runtime.executable_path` | none | overrides platform auto-detection |
| `runtime.user_dir` | none | overrides platform auto-detection |
| `runtime.data_dir` | none | overrides platform auto-detection |
| `rcon.host` | `"localhost"` | |
| `rcon.port` | `27015` | |
| `rcon.password` | none | |
| `http.connect_timeout` | `5` | seconds |
| `http.read_timeout` | `30` | seconds |
| `http.write_timeout` | `30` | seconds |

### Cache

Each cache type (`download`, `api`, `info_json`) has a `backend` selector
(`file_system`, `redis`, `s3`), a `ttl`, and backend-specific nested tables
(`file_system.max_file_size`, `file_system.compression_threshold`,
`redis.url`, `redis.lock_timeout`, `s3.bucket`, `s3.region`, `s3.lock_timeout`).

**Default values by cache type:**

| Setting | `download` | `api` | `info_json` |
|---------|------------|-------|-------------|
| `ttl` | none | `3600` | none |
| `file_system.max_file_size` | none | `10MiB` | none |
| `file_system.compression_threshold` | none | `0` | `0` |

## Configuration Examples

### Redis Cache Backend

```toml
[cache.api]
backend = "redis"

[cache.api.redis]
url = "redis://localhost:6379/0" # or use REDIS_URL env
lock_timeout = 30
```

### S3 Cache Backend

```toml
[cache.download]
backend = "s3"

[cache.download.s3]
bucket = "my-cache-bucket"
region = "ap-northeast-1" # or use AWS_REGION env
lock_timeout = 30
```

## Related Documentation

- [Container (DI)](container.md)
- [Cache System](cache.md)
