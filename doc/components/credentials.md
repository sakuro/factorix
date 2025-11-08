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
credential = ServiceCredential.new
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
credential = APICredential.new
credential.key  # => "sk_live_xxxxxxxxxx"
```

### Consumers

- `PortalAPI` - Upload/publish/edit MODs

## Recommended Management Method

Manage environment variables with **mise** and `.env` file (dotenv gem not required).

### mise.toml (can be committed)

```toml
[tools]
ruby = "3.2"

[env]
_.path = ["bin", "exe"]
_.file = ".env"  # Load environment variables from .env file
```

### .env (gitignore target)

```bash
# Factorio Service authentication (for MOD downloads)
FACTORIO_SERVICE_USERNAME=myusername
FACTORIO_SERVICE_TOKEN=mytoken123

# Factorio API authentication (for Portal API)
FACTORIO_API_KEY=sk_live_xxxxxxxxxx
```

### .gitignore

```
.env
.env.local
```

### Benefits

- No need for dotenv gem (mise loads .env)
- Standard .env naming convention
- IDE .env support available

## dry-container Registration

```ruby
Application.register "service_credential" { ServiceCredential.new }
Application.register "api_credential" { APICredential.new }
```

## Related Documentation

- [API/Portal Layer](api-portal.md)
- [Application Configuration](application.md)
- [Technology Stack](../technology-stack.md)
