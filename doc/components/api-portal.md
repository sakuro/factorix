# API and Portal Layers

## API Layer (Low-level)

Classes that wrap the Mod Portal API.

- **Responsibility**: HTTP communication and JSON parsing
- **Return value**: Hash (parsed JSON)
- **Reference**: https://wiki.factorio.com/Factorio_HTTP_API_usage_guidelines

### Design Policy

Split into three classes based on authentication method.

#### 1. MODListAPI - API without authentication

- Retrieve MOD list
- Retrieve MOD details
- Return value example: `{"results" => [...], "pagination" => {...}}`
- Corresponds to: [Mod portal API](https://wiki.factorio.com/Mod_portal_API)

#### 2. ModDownloadAPI - username + token authentication

- Download MOD files
- Initialization: `ModDownloadAPI.new(username:, token:)`

#### 3. ModManagementAPI - API key authentication

- Upload MODs
- Publish MODs
- Edit MOD details
- Manage MOD images
- Initialization: `ModManagementAPI.new(api_key:)`
- Corresponds to: [Mod upload API](https://wiki.factorio.com/Mod_upload_API)

### Benefits

- Hold only necessary authentication information (improved security)
- Comply with single responsibility principle
- Good compatibility with dry-auto_inject
- Focus on HTTP communication, delegate data conversion to Portal layer

## Available APIs (In Scope)

**Out of scope**: Matchmaking API, Multiplayer authentication API

### Base URLs

- API: `https://mods.factorio.com/api`
- Assets: `https://assets-mod.factorio.com`

### Main Endpoints

#### 1. GET /mods - Retrieve MOD list

**Parameters**:
- `hide_deprecated`: Exclude deprecated MODs
- `page`: Page number
- `page_size`: Page size (or "max")
- `sort`: Sort field (name, created_at, updated_at)
- `sort_order`: Sort order (asc, desc)
- `namelist`: Filter by name (array)
- `version`: Factorio version compatibility (0.13-2.0)

**Response**: MOD list with pagination information

#### 2. GET /mods/{name} - Retrieve MOD basic information

**Response**: MOD metadata and release list

**Response size**: ~1.7KB (51 lines)

**Fields** (7 + 1 optional):
- `category` - MOD category
- `downloads_count` - Download count
- `name` - MOD name
- `owner` - Owner username
- `releases` - Release array (each release contains: `download_url`, `file_name`, `version`, `released_at`, `sha1`, `info_json`)
- `summary` - Brief description
- `title` - MOD title
- `thumbnail` - **Optional**: Thumbnail URL (omitted if MOD has no images)

**Release object structure**:
```json
{
  "download_url": "/download/mod-name/...",
  "file_name": "mod-name_1.0.0.zip",
  "info_json": {
    "factorio_version": "1.1"
  },
  "released_at": "2023-07-16T10:21:18.306000Z",
  "sha1": "d44b7b4a02f3d8ea192d36afe80f61e71a538131",
  "version": "1.0.0"
}
```

#### 3. GET /mods/{name}/full - Retrieve MOD detailed information

**Response**: Basic information + additional details

**Response size**: ~4.4KB (99 lines, 2.6x larger than basic)

**Additional fields in /full** (9 + 1 optional):
- `changelog` - Version history with dates and changes
- `created_at` - MOD creation timestamp (ISO 8601)
- `deprecated` - **Optional**: Boolean flag, only present when `true` (field omitted for non-deprecated MODs)
- `description` - Full description (Markdown format)
- `homepage` - Homepage URL (can be empty string)
- `images` - Image array `[{id, thumbnail, url}, ...]` (empty array if no images)
- `license` - License object `{id, name, title, description, url}`
- `source_url` - Source code repository URL
- `tags` - Tags array
- `updated_at` - Last update timestamp (ISO 8601)

**Most important difference**: The `releases[].info_json` object includes `dependencies` array in the full endpoint:

```json
{
  "info_json": {
    "dependencies": ["base >= 1.1", "Krastorio2"],
    "factorio_version": "1.1"
  }
}
```

This is the **only way** to retrieve dependency information via the API, making the `/full` endpoint essential for dependency resolution.

#### 4. POST /v2/mods/init_upload - Initialize MOD upload

- **Authentication**: API key (`ModPortal: Upload Mods` permission)
- **Response**: Upload URL

#### 5. POST {upload_url} - Complete MOD file upload

- multipart/form-data format

#### 6. POST /v2/mods/init_publish - Initialize MOD publication

- **Authentication**: API key (`ModPortal: Publish Mods` permission)
- **Parameters**: mod name
- **Response**: Upload URL

#### 7. POST {upload_url} - Complete MOD publication

- multipart/form-data format
- **Options**: description, category, license, source_url

#### 8. POST /v2/mods/edit_details - Edit MOD detailed information

- **Authentication**: API key (`ModPortal: Edit Mods` permission)
- **Editable items**: title, summary, description, category, tags, license, homepage, deprecated, source_url, FAQ
- **Limits**: title(250 chars), summary(500 chars), URL(256 chars)

#### 9. POST /v2/mods/images/add - Initialize MOD image addition

- **Authentication**: API key (`ModPortal: Edit Mods` permission)
- **Response**: Image upload URL

#### 10. POST {upload_url} - Complete MOD image upload

- multipart/form-data format
- **Response**: image ID (SHA1), URL, thumbnail URL

#### 11. POST /v2/mods/images/edit - Edit MOD images

- **Authentication**: API key (`ModPortal: Edit Mods` permission)
- **Parameters**: mod name, comma-separated image IDs

### Categories

automation, content, balance, blueprints, combat, fixes, graphics, gui, logistics, map-gen, optimization, overhaul, storage, technology, trains, tweaks, utilities

### Error Handling

- Timeout handling (connection: 5s, read: 10s)
- HTTP error (4xx, 5xx) classification
- Network errors
- SSL/TLS errors
- JSON parsing errors

### Usage Guidelines

- Protect user privacy (proper management of tokens and API keys)
- Respect server resources (exponential backoff on errors)

## Portal Layer (High-level)

Class that wraps the API for more object-oriented handling.

- **Responsibility**: Convert JSON to Types objects, domain logic
- **Return value**: Data.define objects under Types
- Return value example: `Portal#list_mods` → `Types::MODList` instance

### Design Policy

- Convert Hash received from API layer to Types::*
- Implement business logic
- Used directly from CLI layer

## Related Documentation

- [Architecture](../architecture.md)
- [Credentials Management](credentials.md)
- [Transfer Layer](transfer.md)
