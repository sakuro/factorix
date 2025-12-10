# Credentials Management

## ServiceCredential

Authentication credentials for MOD downloads (username + token). Used for authentication with Factorio service.

### Credentials

- `username`: Factorio service username
- `token`: Factorio service token

### Data Sources

The `.load` method automatically selects the credential source:

1. **Environment variables (if both are set)**
   - `FACTORIO_USERNAME`
   - `FACTORIO_TOKEN`
   - Both must be set, or an error is raised

2. **player-data.json (fallback)**
   - `service-username` and `service-token` in `player-data.json`
   - Path: Runtime#player_data_path
   - Automatically saved when you log in to Factorio

### Usage Example

```ruby
credential = ServiceCredential.load

credential.username  # => "myusername"
credential.token     # => "mytoken123"
```

### Consumers

- `DownloadAPI` - Download MOD files

## APICredential

Authentication credentials for Portal API (API key). Used for uploading/publishing/editing MODs.

### Credentials

- `key`: Factorio API key

### Data Sources

- **Environment variables only** (for security reasons)
  - `FACTORIO_API_KEY`
- **Not saved to files** (to prevent accidental Git commits)

### How to Obtain API Key

1. Create API key at https://factorio.com/profile
2. Select required permissions:
   - `ModPortal: Upload Mods` - For uploading MOD files
   - `ModPortal: Publish Mods` - For publishing MODs
   - `ModPortal: Edit Mods` - For editing MOD details and managing images
3. A single API key can have multiple permissions

### Usage

Set in Authorization header as `Bearer {api_key}`.

### Usage Example

```ruby
credential = APICredential.load

credential.api_key  # => "xxxxxxxxxx"
```

### Consumers

- `PortalAPI` - Upload/publish/edit MODs

## Container Registration

```ruby
register(:service_credential, memoize: true) { ServiceCredential.load }

register(:api_credential, memoize: true) { APICredential.load }
```

## Credential Masking in Logs

When downloading MODs, URLs may contain sensitive parameters. These are automatically masked with `*****` in HTTP logs.

### Configuration

Masked parameters are configured via `HTTP::Client` constructor:

```ruby
HTTP::Client.new(masked_params: %w[username token secure])
```

Default: `[]` (no masking)

### Currently Masked Parameters

| Parameter | Description |
|-----------|-------------|
| `username` | Factorio service username |
| `token` | Factorio service token |
| `secure` | CDN redirect signature |

### Log Points

Masking applies to:
- HTTP request logs (initial request)
- HTTP redirect logs

Implementation: `Factorix::HTTP::Client#mask_credentials`

## Related Documentation

- [API/Portal Layer](api-portal.md)
- [Application Configuration](application.md)
- [Technology Stack](../technology-stack.md)
