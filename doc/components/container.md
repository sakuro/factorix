# Container (DI)

Dependency injection container for the library.

## Structure

```ruby
class Container
  extend Dry::Core::Container::Mixin
end
```

## Registered Services

| Key | Description | Memoized |
|-----|-------------|----------|
| `runtime` | Platform runtime detector | Yes |
| `logger` | Logger instance | Yes |
| `retry_strategy` | HTTP retry strategy | Yes |
| `service_credential` | Factorio service credentials | Yes |
| `api_credential` | Portal API credentials | Yes |
| `download_cache` | Cache for MOD files | Yes |
| `api_cache` | Cache for API responses | Yes |
| `info_json_cache` | Cache for MOD metadata | Yes |
| `http_client` | Base HTTP client | Yes |
| `download_http_client` | HTTP client for downloads (with retry) | Yes |
| `api_http_client` | HTTP client for API (with retry + cache) | Yes |
| `upload_http_client` | HTTP client for uploads (with retry) | Yes |
| `downloader` | File downloader | No |
| `uploader` | File uploader | Yes |
| `mod_portal_api` | MOD Portal API client | Yes |
| `mod_download_api` | MOD Download API client | Yes |
| `mod_management_api` | MOD Management API client | Yes |
| `portal` | High-level Portal wrapper | Yes |

Note: `downloader` is not memoized to support independent event handlers for parallel downloads.

## Usage with Dry::AutoInject

```ruby
Import = Dry::AutoInject(Factorix::Container)

class SomeClass
  include Import[:logger, cache: :api_cache]
end
```

## Related Documentation

- [Configuration](configuration.md)
- [Cache System](cache.md)
- [Architecture](../architecture.md)
