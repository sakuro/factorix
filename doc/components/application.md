# Application (Composition Root)

`Factorix::Application` (`lib/factorix/application.rb`) wires the object graph.
The shared instance is available as `Factorix.app`.

## How it works

- Each component is a memoized reader built on first access.
- Writers (`Factorix.app.runtime = ...`) let tests and alternative wiring
  replace a component before its first use.
- Classes take their dependencies as keyword arguments whose defaults resolve
  from `Factorix.app`, so direct construction with explicit dependencies is
  always possible:

```ruby
downloader = Factorix::Transfer::Downloader.new(logger:, cache:, client:)
```

- CLI command classes are instantiated by dry-cli without arguments, so their
  constructors rely on the `Factorix.app` defaults.

## Components

| Reader | Description |
|--------|-------------|
| `runtime` | Platform runtime (auto-detected) |
| `logger` | Application logger (file under state directory) |
| `retry_strategy` | HTTP retry strategy |
| `download_cache` / `api_cache` / `info_json_cache` | Cache backends per type |
| `http_client` | Base HTTP client |
| `download_http_client` | Client → Retry (caching handled by Downloader) |
| `api_http_client` | Client → Cache → Retry |
| `upload_http_client` | Client → Retry |
| `downloader` / `uploader` | File transfer |
| `service_credential` / `api_credential` | Credentials (loaded lazily) |
| `mod_portal_api` / `mod_download_api` / `game_download_api` / `mod_management_api` | API clients |
| `portal` | High-level portal facade |

`mod_management_api` is wired with an `on_mod_changed` callback that invalidates
`mod_portal_api`'s caches after uploads/edits.

## Cache backend selection

`Application#build_cache` maps the configured backend name to its class
explicitly (`file_system` / `redis` / `s3`) — see [cache.md](cache.md) and
[configuration.md](configuration.md).

## Related Documentation

- [Configuration](configuration.md)
- [Cache System](cache.md)
