# Credentials Management

## ServiceCredential

Authentication credentials for MOD downloads (username + token). Used for authentication with Factorio service.

### Credentials

- `username`: Factorio service username
- `token`: Factorio service token

### Data Sources (in priority order)

1. **Environment variables (priority)**
   - `FACTORIO_SERVICE_USERNAME`
   - `FACTORIO_SERVICE_TOKEN`

2. **File (fallback)**
   - `service-username` in `player-data.json`
   - `service-token` in `player-data.json`
   - Path: Runtime#player_data_path

### Usage Example

```ruby
credential = ServiceCredential.from_env
# or
credential = ServiceCredential.from_player_data(runtime:)

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
credential = APICredential.from_env

credential.api_key  # => "xxxxxxxxxx"
```

### Consumers

- `PortalAPI` - Upload/publish/edit MODs

## dry-container Registration

```ruby
register(:service_credential, memoize: true) do
  runtime = resolve(:runtime)
  case config.credential.source
  when :env
    ServiceCredential.from_env
  when :player_data
    ServiceCredential.from_player_data(runtime:)
  else
    raise ArgumentError, "Invalid credential source: #{config.credential.source}"
  end
end

register(:api_credential, memoize: true) do
  APICredential.from_env
end
```

## Related Documentation

- [API/Portal Layer](api-portal.md)
- [Application Configuration](application.md)
- [Technology Stack](../technology-stack.md)
