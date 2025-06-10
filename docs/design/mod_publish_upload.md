# MOD Publishing and Update Feature Implementation Plan

## Overview

Add new MOD publishing and existing MOD update functionality using the Factorio MOD Portal API.

## API Flow

The Factorio MOD Portal API uses a two-step process for MOD publishing and updates:

1. Get a temporary upload URL via authenticated GET request
2. POST the MOD file to the obtained URL

## Implementation Plan

### 1. Authentication Management

Use the environment variable `FACTORIO_MOD_API_KEY` to configure the MOD Portal API access key.
Display an error message and exit if the key is not configured.

### 2. Additional Methods for ModPortal::API Class

Add the following methods to the existing `ModPortal::API` class:

- `get_publish_url`: Get upload URL for initial publishing
- `get_upload_url`: Get upload URL for updates
- `upload_mod_file`: POST file to the obtained URL
- `publish`: Execute the complete publishing process
- `upload`: Execute the complete update process

### 3. ModZipAnalyzer Class Creation

Implement a class for analyzing MOD ZIP files:

- Extract MOD name and version from ZIP filename
- Extract metadata from info.json within the ZIP file
- Validate consistency between filename and info.json

### 4. CLI Command Implementation

#### `publish` Command

```bash
factorix mod publish MOD_FILE.zip
```

Processing:
1. Verify API KEY existence
2. Analyze MOD ZIP file
3. Get publishing URL
4. Upload MOD file

#### `upload` Command

```bash
factorix mod upload MOD_FILE.zip [--changelog TEXT]
```

Processing:
1. Verify API KEY existence
2. Analyze MOD ZIP file
3. Get update URL
4. Upload MOD file (optionally with changelog)

### 5. Error Handling

Handle the following special error cases:

- Authentication error: API KEY is invalid or not configured
- Conflict error: MOD name already exists during initial publishing
- Not found error: Target MOD does not exist during update

### 6. Code Structure

```
lib/
  factorix/
    mod_portal/
      api.rb  # Add to existing file
      error.rb  # Add to existing file
    mod_zip_analyzer.rb  # New file
    cli/
      commands/
        mod/
          publish.rb  # New file
          upload.rb  # New file
```

### 7. Technical Details

#### Upload URL Retrieval (v2 API)

```
GET /api/v2/mods/publish       # New publishing
GET /api/v2/mods/{name}/upload # Update
```

- Required header: `Authorization: Bearer API_KEY`
- Response: JSON containing `upload_url` field

#### File Upload

```
POST {upload_url}
```

- Include MOD ZIP file in `file` field using multipart format
- For updates, `changelog` field can be optionally specified

### 8. MOD Format Validation

- Filename: `{mod_name}_{version}.zip`
- info.json: Existence of required fields (name, version, title, author, description)
- Filename and info.json consistency: MOD name and version must match

## Implementation Considerations

1. Upload URLs are temporary and must be used immediately after retrieval
2. Set longer timeouts for uploads to handle large MOD files
3. Perform file validation beforehand to detect and notify issues before API errors
4. Provide appropriate error messages to guide users on next steps
