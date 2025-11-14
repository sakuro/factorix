# MOD Upload/Publish Command Implementation Plan

## Design Decisions

### CLI Level: Two Commands

#### Upload Command
- `factorix mod upload MOD_FILE.zip [OPTIONS]`
- Always accepts metadata options (--description, --category, --license, --source-url)
- Automatically detects whether mod exists and uses appropriate API
- Combines file upload with metadata update

#### Edit Command
- `factorix mod edit MOD_NAME [OPTIONS]`
- Updates metadata without uploading a new file
- Useful for updating description, category, license after initial upload
- Requires mod to already exist on portal

### Portal Level: Smart Orchestration
- `upload_mod(mod_name, file_path, **metadata)` method
- Checks mod existence via Portal API
- Routes to correct API endpoint
- Handles metadata appropriately based on scenario

### API Level: Separate Low-Level Methods
- `init_publish(mod_name)` - For new mods only
- `init_upload(mod_name)` - For existing mods only
- `edit_details(mod_name, **metadata)` - For updating metadata
- `finish_upload(upload_url, file_path, **optional_metadata)` - Complete upload

## API Differences

### Initial Upload vs Update Upload

| Item | Initial Publication (init_publish) | Update Upload (init_upload) |
|------|-----------------------------------|----------------------------|
| **Endpoint** | `/v2/mods/init_publish` | `/v2/mods/releases/init_upload` |
| **Purpose** | Publish a brand new mod to the portal | Add a new release to existing mod |
| **Required Permission** | `ModPortal: Publish Mods` | `ModPortal: Upload Mods` |
| **Metadata Support** | Accepts description, category, license, source_url | Does NOT accept metadata fields |
| **Failure Case** | Error if mod already exists | Error if mod doesn't exist |

## Implementation Flow

### Scenario 1: First-Time Upload (Mod Doesn't Exist)
```
1. CLI: factorix mod upload my-mod_1.0.0.zip --category content
2. Portal.upload_mod checks: get_mod("my-mod") → 404 (doesn't exist)
3. Portal calls: api.init_publish("my-mod") → returns upload_url
4. Portal calls: api.finish_upload(upload_url, file, category: "content")
5. Success: Mod created with metadata
```

### Scenario 2: Update Upload (Mod Exists)
```
1. CLI: factorix mod upload my-mod_1.1.0.zip --description "New features"
2. Portal.upload_mod checks: get_mod("my-mod") → 200 (exists)
3. Portal calls: api.init_upload("my-mod") → returns upload_url
4. Portal calls: api.finish_upload(upload_url, file)
5. Portal calls: api.edit_details("my-mod", description: "New features")
6. Success: New release added, metadata updated
```

### Scenario 3: Edit Metadata (No Upload)
```
1. CLI: factorix mod edit my-mod --description "Updated description" --category content
2. Portal.edit_mod calls: api.edit_details("my-mod", description: "Updated description", category: "content")
3. Success: Metadata updated without uploading new file
```

## Architecture

```
CLI Layer
  Upload command:
    - Automatic detection: Check mod existence
    - Always accept metadata
    - Handle both scenarios transparently
  Edit command:
    - Metadata-only updates
    - No file upload required
    - Direct call to Portal.edit_mod
      ↓
Portal Layer
  - upload_mod(mod_name, file_path, **metadata)
    - Auto-detect and route to correct API
    - Manage metadata placement appropriately
  - edit_mod(mod_name, **metadata)
    - Direct wrapper for edit_details API
      ↓
API Layer (MODManagementAPI)
  - init_publish(mod_name) - For initial publication only
  - init_upload(mod_name) - For updates only
  - edit_details(mod_name, **metadata) - For metadata editing only
  - finish_upload(upload_url, file_path, **optional_metadata)
  - Low-level APIs, implemented separately
```

## Files to Create

### 1. API Layer
**lib/factorix/api/mod_management_api.rb**
```ruby
class MODManagementAPI
  include Factorix::Import["api_credential", "http", "logger"]

  BASE_URL = "https://mods.factorio.com"

  # Initialize new mod publication
  # @param mod_name [String] the mod name
  # @return [String] upload URL
  def init_publish(mod_name)
    # POST /v2/mods/init_publish
    # Headers: Authorization: Bearer {api_key}
    # Body: { "mod" => mod_name }
    # Returns: { "upload_url" => "..." }
  end

  # Initialize update to existing mod
  # @param mod_name [String] the mod name
  # @return [String] upload URL
  def init_upload(mod_name)
    # POST /v2/mods/releases/init_upload
    # Headers: Authorization: Bearer {api_key}
    # Body: { "mod" => mod_name }
    # Returns: { "upload_url" => "..." }
  end

  # Complete upload (works for both scenarios)
  # @param upload_url [String] the upload URL from init
  # @param file_path [Pathname, String] path to mod zip file
  # @param metadata [Hash] optional metadata (only for publish)
  # @option metadata [String] :description Markdown description
  # @option metadata [String] :category Mod category
  # @option metadata [String] :license License identifier
  # @option metadata [String] :source_url Repository URL
  # @return [void]
  def finish_upload(upload_url, file_path, **metadata)
    # POST to upload_url with multipart/form-data
    # Required field: file
    # Optional fields (publish only): description, category, license, source_url
  end

  # Edit mod details (for post-upload metadata changes)
  # @param mod_name [String] the mod name
  # @param metadata [Hash] metadata to update
  # @return [void]
  def edit_details(mod_name, **metadata)
    # POST /v2/mods/edit_details
    # Params: description, category, license, source_url, etc.
  end

  private

  def build_auth_header
    { "Authorization" => "Bearer #{api_credential.api_key}" }
  end
end
```

**spec/factorix/api/mod_management_api_spec.rb**
- Test init_publish with valid mod name
- Test init_upload with existing mod
- Test finish_upload with/without metadata
- Test edit_details with various metadata
- Test error handling (InvalidApiKey, Forbidden, etc.)
- Mock HTTP responses with WebMock

**sig/factorix/api/mod_management_api.rbs**
```rbs
module Factorix
  module API
    class MODManagementAPI
      @api_credential: APICredential
      @http: Transfer::HTTP
      @logger: Dry::Logger::Dispatcher

      def init_publish: (String mod_name) -> String
      def init_upload: (String mod_name) -> String
      def finish_upload: (String upload_url, Pathname | String file_path, **untyped metadata) -> void
      def edit_details: (String mod_name, **untyped metadata) -> void
    end
  end
end
```

### 2. Portal Layer
**Modify lib/factorix/portal.rb**
```ruby
# Add to imports
include Factorix::Import["mod_portal_api", "mod_download_api", "mod_management_api", "logger"]

# Upload a mod file to the portal
# Automatically detects if this is a new mod or update
# @param mod_name [String] the mod name
# @param file_path [Pathname, String] path to mod zip file
# @param metadata [Hash] optional metadata
# @option metadata [String] :description Markdown description
# @option metadata [String] :category Mod category
# @option metadata [String] :license License identifier
# @option metadata [String] :source_url Repository URL
# @return [void]
def upload_mod(mod_name, file_path, **metadata)
  file_path = Pathname(file_path) unless file_path.is_a?(Pathname)

  # Check if mod exists
  mod_exists = begin
    get_mod(mod_name)
    logger.info("Uploading new release to existing mod", mod: mod_name)
    true
  rescue Errors::HTTPClientError => e
    raise unless e.status == 404
    logger.info("Publishing new mod", mod: mod_name)
    false
  end

  # Initialize upload with appropriate endpoint
  upload_url = if mod_exists
    mod_management_api.init_upload(mod_name)
  else
    mod_management_api.init_publish(mod_name)
  end

  # Complete upload
  if mod_exists
    # For existing mods: upload file, then edit metadata separately
    mod_management_api.finish_upload(upload_url, file_path)
    mod_management_api.edit_details(mod_name, **metadata) unless metadata.empty?
  else
    # For new mods: upload file with metadata
    mod_management_api.finish_upload(upload_url, file_path, **metadata)
  end

  logger.info("Upload completed successfully", mod: mod_name)
end

# Edit mod metadata without uploading new file
# @param mod_name [String] the mod name
# @param metadata [Hash] metadata to update
# @option metadata [String] :description Markdown description
# @option metadata [String] :category Mod category
# @option metadata [String] :license License identifier
# @option metadata [String] :source_url Repository URL
# @return [void]
def edit_mod(mod_name, **metadata)
  raise ArgumentError, "No metadata provided" if metadata.empty?

  logger.info("Editing mod metadata", mod: mod_name)
  mod_management_api.edit_details(mod_name, **metadata)
  logger.info("Metadata updated successfully", mod: mod_name)
end
```

**Update sig/factorix/portal.rbs**
```rbs
module Factorix
  class Portal
    @mod_portal_api: API::MODPortalAPI
    @mod_download_api: API::MODDownloadAPI
    @mod_management_api: API::MODManagementAPI
    @logger: Dry::Logger::Dispatcher

    def upload_mod: (String mod_name, Pathname | String file_path, **untyped metadata) -> void
    def edit_mod: (String mod_name, **untyped metadata) -> void
  end
end
```

### 3. Application Container
**Modify lib/factorix/application.rb**
```ruby
# Register API credential
register(:api_credential, memoize: true) do
  Factorix::APICredential.from_env
end

# Register mod management API
register(:mod_management_api, memoize: true) do
  Factorix::API::MODManagementAPI.new
end
```

### 4. CLI Command
**lib/factorix/cli/commands/mod/upload.rb**
```ruby
module Factorix
  class CLI
    module Commands
      module MOD
        class Upload < Dry::CLI::Command
          include Factorix::Import[portal: "portal", http: "http", logger: "logger"]

          desc "Upload MOD file to Factorio MOD Portal"

          argument :mod_file, required: true, desc: "MOD file path (*.zip)"

          option :description, desc: "Mod description (Markdown format)"
          option :category, desc: "Mod category (e.g., content, automation)"
          option :license, desc: "License identifier (e.g., MIT)"
          option :source_url, desc: "Source code repository URL"

          def call(mod_file:, **options)
            # 1. Validate file
            file_path = Pathname(mod_file)
            raise ArgumentError, "File not found: #{mod_file}" unless file_path.exist?
            raise ArgumentError, "File must be a .zip file" unless file_path.extname == ".zip"

            # 2. Extract mod name from info.json in ZIP
            mod_name = extract_mod_name(file_path)
            logger.info("Uploading mod", file: file_path.to_s, mod: mod_name)

            # 3. Set up progress handler
            setup_progress_handler

            # 4. Build metadata from options
            metadata = options.compact

            # 5. Upload
            portal.upload_mod(mod_name, file_path, **metadata)

            puts "Upload completed successfully!"
          rescue => e
            logger.error("Upload failed", error: e.message)
            raise
          end

          private

          def extract_mod_name(zip_path)
            # Read info.json from ZIP and extract "name" field
            # Implementation using rubyzip gem
          end

          def setup_progress_handler
            # Subscribe to http upload events and display progress bar
            # Similar to download command implementation
          end
        end
      end
    end
  end
end
```

**spec/factorix/cli/commands/mod/upload_spec.rb**
- Test file validation (exists, .zip extension)
- Test mod name extraction
- Test successful upload
- Test with metadata options
- Test error handling

**lib/factorix/cli/commands/mod/edit.rb**
```ruby
module Factorix
  class CLI
    module Commands
      module MOD
        class Edit < Dry::CLI::Command
          include Factorix::Import[portal: "portal", logger: "logger"]

          desc "Edit MOD metadata on Factorio MOD Portal"

          argument :mod_name, required: true, desc: "MOD name"

          option :description, desc: "Mod description (Markdown format)"
          option :category, desc: "Mod category (e.g., content, automation)"
          option :license, desc: "License identifier (e.g., MIT)"
          option :source_url, desc: "Source code repository URL"

          def call(mod_name:, **options)
            # 1. Validate options
            metadata = options.compact
            if metadata.empty?
              puts "Error: At least one metadata option must be provided"
              puts "Available options: --description, --category, --license, --source-url"
              exit 1
            end

            # 2. Edit metadata
            logger.info("Editing mod metadata", mod: mod_name)
            portal.edit_mod(mod_name, **metadata)

            puts "Metadata updated successfully!"
          rescue => e
            logger.error("Edit failed", error: e.message)
            raise
          end
        end
      end
    end
  end
end
```

**spec/factorix/cli/commands/mod/edit_spec.rb**
- Test successful metadata edit
- Test error when no metadata options provided
- Test with various metadata combinations
- Test error handling (UnknownMod, InvalidApiKey, etc.)

## Implementation Steps

### Phase 1: API Layer (Low-Level)
1. ✅ Research API documentation (completed)
2. Create MODManagementAPI class
3. Implement init_publish method
4. Implement init_upload method
5. Implement finish_upload method
6. Implement edit_details method
7. Write comprehensive tests
8. Create RBS signatures

### Phase 2: Container Registration
1. Add api_credential registration to Application
2. Add mod_management_api registration to Application

### Phase 3: Portal Layer (Orchestration)
1. Add mod_management_api to Portal imports
2. Implement upload_mod with auto-detection logic
3. Implement edit_mod method
4. Handle metadata routing (publish vs edit)
5. Update RBS signatures
6. Write tests

### Phase 4: CLI Commands
1. Create Upload command class
   - Add file validation logic
   - Implement mod name extraction from ZIP
   - Implement progress display
   - Handle metadata options
   - Write tests
2. Create Edit command class
   - Add metadata validation logic
   - Handle metadata options
   - Write tests

### Phase 5: Integration Testing
1. Test upload with mock mod files
2. Test edit with various metadata combinations
3. Verify auto-detection logic
4. Test metadata handling in both scenarios
5. Manual testing with real API (if API key available)

## Key Technical Details

### Authentication
- API Key from environment variable: `FACTORIO_API_KEY`
- Required permissions:
  - `ModPortal: Publish Mods` for init_publish
  - `ModPortal: Upload Mods` for init_upload
  - `ModPortal: Edit Mods` for edit_details
- Bearer token format: `Authorization: Bearer {api_key}`

### Metadata Fields
- **description**: String, Markdown format, full description
- **category**: String, one of: automation, content, balance, blueprints, combat, fixes, graphics, gui, logistics, map-gen, optimization, overhaul, storage, technology, trains, tweaks, utilities
- **license**: String, license identifier (see API docs for valid values)
- **source_url**: String, repository URL (max 256 characters)

### Request Formats

**init_publish / init_upload**:
```ruby
POST /v2/mods/init_publish
Headers: Authorization: Bearer {api_key}
Content-Type: application/json
Body: { "mod": "mod-name" }

Response: { "upload_url": "https://..." }
```

**finish_upload**:
```ruby
POST {upload_url}
Content-Type: multipart/form-data
Fields:
  - file: (binary, required)
  - description: (string, optional, publish only)
  - category: (string, optional, publish only)
  - license: (string, optional, publish only)
  - source_url: (string, optional, publish only)

Response: { "success": true }
```

**edit_details**:
```ruby
POST /v2/mods/edit_details
Headers: Authorization: Bearer {api_key}
Content-Type: application/json
Body: {
  "mod": "mod-name",
  "description": "...",
  "category": "...",
  ...
}
```

### Error Handling
- HTTP 4xx → `HTTPClientError`
- HTTP 5xx → `HTTPServerError`
- API Error Codes:
  - `InvalidApiKey` - API key invalid or missing required permissions
  - `Forbidden` - Insufficient permissions
  - `UnknownMod` - Mod doesn't exist (for init_upload)
  - `ModAlreadyExists` - Mod already exists (for init_publish)
  - `InvalidModRelease` - info.json validation failed
  - `InvalidModUpload` - ZIP file or filename validation failed
  - `InvalidRequest` - Malformed request
  - `InternalError` - Server error

### Progress Display
- Subscribe to HTTP events: `upload.started`, `upload.progress`, `upload.completed`
- Display progress bar during file upload
- Show upload speed and ETA
- Indicate operation type (publishing new mod vs updating existing mod)

## Success Criteria
- ✅ Upload command handles both publish and update scenarios
- ✅ Edit command allows metadata-only updates
- ✅ Metadata always accepted and properly routed
- ✅ Clear feedback about what operation was performed
- ✅ Comprehensive test coverage
- ✅ Type-safe RBS signatures
- ✅ Proper error handling and user messages
- ✅ Progress display during upload

## References
- Factorio Mod Portal API: https://wiki.factorio.com/Mod_portal_API
- Existing documentation: `doc/components/api-portal.md`
- Similar implementation: `lib/factorix/cli/commands/mod/download.rb`
