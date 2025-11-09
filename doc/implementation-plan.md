# Implementation Plan

This document tracks the implementation progress of the Factorix reimplementation project.

## Implementation Strategy

- **Bottom-up approach**: Start with components that have no dependencies
- **Incremental testing**: Write tests for each component before moving to the next
- **Reference existing code**: Use `factorix.old/` as reference when available
- **Data-driven design**: Implement API layer first, then design Types based on actual responses

## Phase 1: Foundation Layer

Components with no external dependencies.

### 1.1 Runtime ✅ COMPLETED

Platform abstraction layer for cross-platform compatibility.

- [x] `runtime/base.rb` - Abstract base class
  - [x] `#user_dir` - Abstract method (NotImplementedError)
  - [x] `#mods_dir` - Derived from user_dir (user_dir + "mods")
  - [x] `#player_data_path` - Derived from user_dir (user_dir + "player-data.json")
  - [x] `#xdg_cache_home_dir` - XDG cache directory (platform-aware defaults)
  - [x] `#xdg_config_home_dir` - XDG config directory (platform-aware defaults)
  - [x] `#xdg_data_home_dir` - XDG data directory (platform-aware defaults)
- [x] `runtime/linux.rb` - Linux implementation (partial: XDG methods only, user_dir NotImplementedError)
- [x] `runtime/mac_os.rb` - macOS implementation (full)
- [x] `runtime/windows.rb` - Windows implementation (AppData support)
- [x] `runtime/wsl.rb` - WSL implementation (inherits Windows)
- [x] `runtime.rb` - Platform detection and factory
- [x] Tests: `spec/factorix/runtime/**/*_spec.rb`
- [x] Zeitwerk inflection: `"mac_os" => "MacOS"`, `"wsl" => "WSL"`

**Reference**: `factorix.old/lib/factorix/runtime/`

**Dependencies**: None

### 1.2 Error Hierarchy (Partial)

Simple error class hierarchy.

- [x] `errors.rb` - Define error classes (partial implementation)
  - [x] `Factorix::Error` - Base error
  - [x] `Factorix::InfrastructureError` - Infrastructure layer errors
  - [x] `Factorix::FileFormatError` - File format errors
  - [x] `Factorix::UnknownPropertyType` - Unknown property type error
  - [ ] Network errors (timeout, connection, etc.)
  - [ ] API errors (authentication, not found, etc.)
  - [ ] Validation errors
- [ ] Tests: `spec/factorix/errors_spec.rb`
- [x] Zeitwerk ignore: `loader.ignore("#{__dir__}/factorix/errors.rb")`

**Dependencies**: None

### 1.3 SerDes (Serialization/Deserialization) ✅ COMPLETED

Binary data format handling for Factorio game files.

- [x] `ser_des/serializer.rb` - Binary serialization
  - [x] Basic types (u8, u16, u32, bool, string, double)
  - [x] Space-optimized integers (optim_u16, optim_u32)
  - [x] Property tree serialization (nil, bool, number, string, list, dictionary)
  - [x] RGBA color conversion ("rgba:RRGGBBAA" ↔ dictionary)
  - [x] UTF-8 encoding validation
  - [x] Long integers (signed/unsigned 64-bit)
- [x] `ser_des/deserializer.rb` - Binary deserialization
  - [x] Basic types (u8, u16, u32, bool, string, double)
  - [x] Space-optimized integers (optim_u16, optim_u32)
  - [x] Property tree deserialization (nil, bool, number, string, list, dictionary)
  - [x] RGBA color conversion (dictionary → "rgba:RRGGBBAA")
  - [x] UTF-8 encoding support
  - [x] Long integers (signed/unsigned 64-bit)
- [x] ~~`ser_des/game_version.rb`~~ - Moved to `types/game_version.rb` (Phase 4.1)
- [x] ~~`ser_des/mod_version.rb`~~ - Moved to `types/mod_version.rb` (Phase 4.1)
- [x] Tests: `spec/factorix/ser_des/**/*_spec.rb`
  - [x] 128 examples, 0 failures
  - [x] Line Coverage: 92.66% (202/218)
  - [x] Branch Coverage: 85.71% (54/63)
  - [x] Boundary value tests (255 for space-optimized)
  - [x] Multibyte UTF-8 string tests
  - [x] Encoding validation tests
**Reference**: `factorix.old/lib/factorix/ser_des/`

**Dependencies**: Errors (UnknownPropertyType), Types (MODVersion, GameVersion)

## Phase 2: Authentication & Configuration

### 2.1 Credentials

Authentication credentials for API access.

- [x] `service_credential.rb` - username + token (MOD downloads)
  - [x] Load from `player-data.json` via Runtime
  - [x] Load from environment variables (FACTORIO_USERNAME, FACTORIO_TOKEN)
- [x] `api_credential.rb` - API key (MOD Upload/Publish API)
  - [x] Load from environment variables (FACTORIO_API_KEY)
- [x] Tests: `spec/factorix/service_credential_spec.rb`
- [x] Tests: `spec/factorix/api_credential_spec.rb`
- [x] RBS: `sig/factorix/service_credential.rbs`
- [x] RBS: `sig/factorix/api_credential.rbs`

**Reference**:
- ServiceCredential: https://wiki.factorio.com/Mod_portal_API
- APICredential: https://wiki.factorio.com/Mod_upload_API

**Dependencies**: Runtime

### 2.2 Application

DI container and configuration management.

- [x] `application.rb` - dry-container + dry-configurable
  - [x] Configuration settings (cache_dir, log_level, http timeouts)
  - [x] Container registration (runtime)
  - [ ] Container registration (cache, logger, retry_strategy, credentials) - deferred
  - [x] Load configuration from `Runtime#factorix_config_path`
- [x] `Import = Dry::AutoInject(Factorix::Application)` for DI
- [x] Tests: `spec/factorix/application_spec.rb`
- [x] RBS: `sig/factorix/application.rbs`
- [x] RBS: Minimal dry-rb type definitions

**Dependencies**: Runtime, Credentials

## Phase 3: External Communication (Low-level)

HTTP communication layer that works with raw Hash data.

### 3.1 Transfer ✅ COMPLETED

File transfer with retry and progress notification using dry-events.

- [x] Add dependencies: `dry-events ~> 1.1`, `retriable ~> 3.1`, `ruby-progressbar ~> 1.13`
- [x] `transfer/retry_strategy.rb` - Wrapper for retriable gem
  - [x] Exponential backoff configuration
  - [x] Retry conditions (network errors, timeouts)
  - [ ] **Future**: Use `Import["logger"]` instead of `warn` for retry callbacks
- [x] `transfer/http.rb` - net/http wrapper with event publishing
  - [x] Include `Dry::Events::Publisher[:transfer]`
  - [x] Register events: `download.started`, `download.progress`, `download.completed`
  - [x] Register events: `upload.started`, `upload.progress`, `upload.completed`
  - [x] Resume support for downloads
  - [x] Publish events during chunk read/write
  - [x] Timeout configuration from Application.config
  - [x] Exception-based error handling (HTTPClientError, HTTPServerError)
  - [x] Internal redirect handling (up to MAX_REDIRECTS=10)
- [x] `transfer/downloader.rb` - File download with caching
  - [x] Use Transfer::HTTP
  - [x] Cache::FileSystem integration
  - [x] File locking for concurrent downloads
  - [x] Automatic cache-or-download logic
  - [x] Temporary file cleanup
  - [x] Exception-based error handling
- [x] `transfer/uploader.rb` - File upload (multipart/form-data)
  - [x] Use Transfer::HTTP
  - [x] Build multipart/form-data format
  - [x] Exception-based error handling
- [x] `progress/bar.rb` - Event listener for ruby-progressbar
  - [x] Implement `on_download_started`, `on_download_progress`, `on_download_completed`
  - [x] Implement `on_upload_started`, `on_upload_progress`, `on_upload_completed`
- [x] Tests: `spec/factorix/transfer/**/*_spec.rb`
  - [x] 315 examples, 0 failures
  - [x] Line Coverage: 96.48%, Branch Coverage: 83.78%
- [x] Tests: Use WebMock for HTTP stubbing
- [x] Tests: Verify event publishing
- [x] RuboCop: All offenses corrected

**Dependencies**: dry-events

**References**:
- [Design comparison](../design-comparison-progress-notification.md)
- [Transfer components](components/transfer.md)

### 3.2 API Layer (Partial)

Low-level API wrappers returning Hash (parsed JSON).

- [x] `api/mod_list_api.rb` - MOD list endpoints (no auth)
  - [x] `GET /api/mods` - List MODs with pagination
  - [x] `GET /api/mods/{name}` - Basic MOD info
  - [x] `GET /api/mods/{name}/full` - Full MOD info with dependencies
  - [x] Query parameter normalization for cache efficiency
  - [x] Cache support via `api_cache`
- [x] `api/mod_download_api.rb` - Download endpoints (ServiceCredential)
  - [x] Download MOD files with username + token parameters
  - [x] Application container registration with configurable credential source
  - [x] Tests: 4 examples, 0 failures
- [ ] `api/mod_management_api.rb` - Portal management endpoints (APICredential)
  - [ ] `POST /v2/mods/releases/init_upload` - Initialize upload
  - [ ] `POST /v2/mods/releases/init_publish` - Initialize publish
  - [ ] `POST /v2/mods/edit_details` - Edit MOD details
  - [ ] `POST /v2/mods/images/add` - Add images
  - [ ] `POST /v2/mods/images/edit` - Edit image order
- [x] Tests: `spec/factorix/api/mod_list_api_spec.rb` (13 examples)
- [x] Tests: `spec/factorix/api/mod_download_api_spec.rb` (4 examples)
- [x] Error handling (HTTPClientError, HTTPServerError)
- [x] Application container registration (`:mod_list_api`, `:mod_download_api`, `:service_credential`)
- [x] RBS type signatures
- [x] Configuration: `config.credential.source` (:player_data or :env)

**Reference**: Test actual API responses to inform Types design
- https://wiki.factorio.com/Mod_portal_API
- https://wiki.factorio.com/Mod_upload_API

**Dependencies**: Transfer, Credentials

## Phase 4: Data Models (High-level)

Immutable value objects based on actual API responses.

### 4.1 Types ✅ COMPLETED

Value objects using Data.define (Ruby 3.2+).

- [x] `types/mod_version.rb` - MOD version (3 × u8: major.minor.patch)
  - [x] Moved from ser_des/ to types/
  - [x] Reimplemented with Data.define for immutable value objects
  - [x] Factory methods (.from_string, .from_numbers) with private constructors
  - [x] Validation: uint8 (0-255) for each component
  - [x] Comparable support, to_s, to_a methods
- [x] `types/game_version.rb` - Game version (4 × u16: major.minor.patch-build)
  - [x] Moved from ser_des/ to types/
  - [x] Reimplemented with Data.define for immutable value objects
  - [x] Factory methods (.from_string, .from_numbers) with private constructors
  - [x] Validation: uint16 (0-65535) for each component
  - [x] Comparable support, to_s, to_a methods
- [x] `types/category.rb` - MOD category (content, overhaul, tweaks, utilities, scenarios, mod-packs, localizations, internal)
  - [x] Flyweight pattern for predefined category instances
  - [x] NO_CATEGORY constant for missing/unassigned category
  - [x] From/to string conversion via `.for(value)` class method
  - [x] Private constants: NO_CATEGORY, CONTENT, OVERHAUL, TWEAKS, UTILITIES, SCENARIOS, MOD_PACKS, LOCALIZATIONS, INTERNAL
- [x] `types/release.rb` - MOD release information
  - [x] Uses MODVersion type (not String) for version field
  - [x] Converts released_at to Time object (UTC)
  - [x] Converts download_url to URI::HTTPS (prepends `https://mods.factorio.com`)
  - [x] Handles info_json metadata
  - [x] SHA1 checksum validation support
- [x] `types/image.rb` - MOD screenshot/image data
  - [x] Converts thumbnail URL to URI::HTTPS
  - [x] Converts full image URL to URI::HTTPS
  - [x] Used in MODInfo::Detail for Full API responses
- [x] `types/license.rb` - License information
  - [x] id, name, title, description attributes
  - [x] Converts url to URI::HTTPS
  - [x] Used in MODInfo::Detail for Full API responses
- [x] `types/mod_info.rb` - Unified MOD information for all API endpoints
  - [x] **Single type for list/Short/Full APIs**: Instead of separate types, uses optional Detail
  - [x] **List API** (`/api/mods`) support: basic fields + latest_release
  - [x] **Short API** (`/api/mods/{name}`) support: same as list
  - [x] **Full API** (`/api/mods/{name}/full`) support: includes nested Detail
  - [x] Nested `MODInfo::Detail` class for Full API-specific fields:
    - changelog, created_at, updated_at, last_highlighted_at
    - description, source_url, homepage, faq
    - tags, license, images, deprecated
  - [x] **Default value strategy** to minimize nil checks:
    - Empty strings: `summary`, `changelog`, `description`, `faq`
    - Empty arrays: `releases`, `tags`, `images`
    - Special constants: `Category.NO_CATEGORY`, `score: 0.0`, `deprecated: false`
  - [x] **URI conversions**:
    - `thumbnail`: prepends `https://assets-mod.factorio.com` + path
    - `homepage`: URI | String union type (attempts parse, falls back to String)
  - [x] **Detail detection**: Checks for required fields (`created_at`, `updated_at`, `homepage`)
  - [x] `MODInfo::Detail#deprecated?` predicate method
  - [x] Replaces deprecated `MODListEntry` type
- ~~`types/mod_list_entry.rb`~~ - **Deleted** (replaced by unified MODInfo)
- ~~`types/pagination.rb`~~ - Not implemented (API returns all results)
- ~~`types/pagination_links.rb`~~ - Not implemented (API returns all results)
- [ ] `types/mod_list.rb` - List container (deferred)
- [x] Tests: `spec/factorix/types/**/*_spec.rb`
  - [x] 344 examples, 0 failures
  - [x] Line Coverage: 96.91%, Branch Coverage: 84.17%
  - [x] Tests for Image, License, Release (URI conversion)
  - [x] Tests for MODInfo (list/Short/Full scenarios)
  - [x] Tests for default values and Detail detection
  - [x] Real API integration tests with space-exploration MOD
- [x] RBS type signatures for all types
  - [x] `sig/factorix/types/image.rbs`
  - [x] `sig/factorix/types/license.rbs`
  - [x] `sig/factorix/types/mod_info.rbs` (including Detail nested class)
  - [x] `sig/factorix/types/release.rbs` (updated for URI)
  - [x] Steep type check: No errors 🫖
- [x] Zeitwerk inflection: `"mod_version" => "MODVersion"`, `"mod_info" => "MODInfo"`

**Dependencies**: None (pure data structures)

### 4.2 MOD Dependencies

Dependency parsing and validation.

- [ ] `mod_dependency.rb` - Single dependency (Data.define)
  - [ ] Type: required, optional, incompatible, hidden, load-neutral
  - [ ] Version constraints parsing
- [ ] `mod_dependency_parser.rb` - Parse dependency strings
  - [ ] Parse `! name`, `? name`, `(?) name`, `~name`, `name >= 1.0.0`
- [ ] `mod_dependencies.rb` - Dependency collection management
  - [ ] List required/optional/incompatible dependencies
  - [ ] Validate compatibility
  - [ ] Circular dependency detection
- [ ] Tests: `spec/factorix/mod_dependency*_spec.rb`

**Reference**: `factorix.old/lib/factorix/mod_dependency*.rb`

**Dependencies**: Types

### 4.3 Portal ✅ COMPLETED

High-level API wrapper converting Hash to Types.

- [x] `portal.rb` - Object-oriented API wrapper
  - [x] `#list_mods(**params)` → `Array[Types::MODInfo]`
  - [x] `#get_mod(name)` → `Types::MODInfo` (Short API)
  - [x] `#get_mod_full(name)` → `Types::MODInfo` (Full API with Detail)
  - [x] `#download_mod(release, output)` → void
  - [x] Uses dry-auto_inject for dependency injection (mod_list_api, mod_download_api)
  - [ ] Upload/Publish/Edit endpoints (deferred until MODManagementAPI)
- [x] Hash → Types conversion logic
  - [x] Converts API response hashes to MODInfo objects
  - [x] Filters deprecated fields (github_path) when creating Detail
- [x] Tests: `spec/factorix/portal_spec.rb`
  - [x] 5 examples, 0 failures
- [x] RBS: `sig/factorix/portal.rbs`
- [x] Application container registration (`:portal`)

**Implementation Notes**:
- Method naming: `get_mod` (not `get_mod_info`) to match API layer
- Latest release: Use `releases.max_by(&:released_at)` (order not guaranteed)
- Deprecated fields: Filtered via `allowed_keys.slice` before Detail.new

**Dependencies**: API, Types

## Phase 5: Storage Layer

Local file and cache management.

### 5.1 Cache ✅ COMPLETED

File-based caching for downloads and API responses.

- [x] `cache/file_system.rb` - File system based cache implementation
  - [x] Key-value storage with SHA1 hashing
  - [x] Two-level directory structure (first 2 chars as prefix)
  - [x] TTL support with age tracking
  - [x] Individual file size limits
  - [x] File locking for concurrent access (flock)
  - [x] `#key_for` - Generate cache key from URL
  - [x] `#exist?` - Check if cache entry exists and is not expired
  - [x] `#fetch` - Copy cached file to output path
  - [x] `#read` - Read cached content as string with encoding support
  - [x] `#store` - Store file in cache (returns false if size exceeds limit)
  - [x] `#delete` - Delete specific cache entry
  - [x] `#clear` - Clear all cache entries
  - [x] `#age` - Get cache entry age in seconds
  - [x] `#expired?` - Check if cache entry has expired
  - [x] `#with_lock` - Execute block with file lock
- [x] Application configuration
  - [x] Separate `download_cache` and `api_cache` registrations
  - [x] Download cache: no TTL, no size limit (MOD files are immutable)
  - [x] API cache: 1 hour TTL, 1MB size limit (JSON responses)
- [x] Tests: `spec/factorix/cache/file_system_spec.rb`
  - [x] 33 examples, 0 failures
  - [x] TTL expiration tests
  - [x] File size limit tests
  - [x] Lock file lifecycle tests
  - [x] Encoding support tests

**Dependencies**: Runtime

### 5.2 MOD Management

Local MOD file and configuration management.

- [ ] `mod.rb` - Local MOD representation (Data.define)
  - [ ] info.json parsing
  - [ ] File path, name, version
- [ ] `mod_state.rb` - MOD enabled/disabled state
- [ ] `mod_list.rb` - mod-list.json management
  - [ ] Read/write `Runtime#mods_dir / "mod-list.json"`
  - [ ] Enable/disable MODs
- [ ] `mod_settings.rb` - mod-settings.dat management
  - [ ] Read/write binary format using SerDes
  - [ ] TOML conversion for human editing
- [ ] Tests: `spec/factorix/mod*_spec.rb`

**Dependencies**: Runtime, SerDes

## Phase 6: CLI Layer

Command-line interface using dry-cli.

### 6.1 CLI Framework

- [ ] `cli.rb` - dry-cli Registry setup
- [ ] `cli/commands.rb` - Command base classes
- [ ] TIntMe style definitions (ERROR_STYLE, SUCCESS_STYLE, etc.)
- [ ] Tests: `spec/factorix/cli_spec.rb`

**Dependencies**: All lower layers

### 6.2 Info & Launch Commands

- [ ] `cli/commands/info.rb` - Display directory information
- [ ] `cli/commands/launch.rb` - Launch Factorio
  - [ ] Pass options to game
  - [ ] Prevent multiple launches
  - [ ] Wait for termination (certain commands)
- [ ] Tests: `spec/factorix/cli/commands/info_spec.rb`
- [ ] Tests: `spec/factorix/cli/commands/launch_spec.rb`

**Dependencies**: Runtime

### 6.3 MOD Commands

- [ ] `cli/commands/mod/list.rb` - List MODs
- [ ] `cli/commands/mod/enable.rb` - Enable MOD
- [ ] `cli/commands/mod/disable.rb` - Disable MOD
- [ ] `cli/commands/mod/download.rb` - Download MOD file
  - [ ] `--output` option for destination
  - [ ] Version specification support (`mod@version`)
- [ ] `cli/commands/mod/install.rb` - Install MOD with dependencies
  - [ ] Three-phase workflow (gather, validate, execute)
  - [ ] Dependency resolution
  - [ ] Version conflict detection
- [ ] `cli/commands/mod/uninstall.rb` - Uninstall MOD
  - [ ] Reverse dependency check
- [ ] `cli/commands/mod/publish.rb` - Publish new MOD
- [ ] `cli/commands/mod/edit.rb` - Edit MOD details on portal
- [ ] Tests: `spec/factorix/cli/commands/mod/**/*_spec.rb`

**Dependencies**: Portal, MODList, MODDependencies

### 6.4 MOD Image Commands

- [ ] `cli/commands/mod/image/list.rb` - List MOD images
- [ ] `cli/commands/mod/image/add.rb` - Add images
- [ ] `cli/commands/mod/image/edit.rb` - Reorder images
- [ ] Tests: `spec/factorix/cli/commands/mod/image/**/*_spec.rb`

**Dependencies**: Portal

### 6.5 MOD Settings Commands

- [ ] `cli/commands/mod/settings/load.rb` - Generate mod-settings.dat from TOML
- [ ] `cli/commands/mod/settings/dump.rb` - Dump mod-settings.dat to TOML
- [ ] Tests: `spec/factorix/cli/commands/mod/settings/**/*_spec.rb`

**Dependencies**: MODSettings

## Testing Strategy

- **Unit tests**: Test each component in isolation
- **WebMock**: Stub HTTP requests in API/Transfer tests
- **Integration tests**: Test CLI commands end-to-end (optional, later phase)
- **RSpec**: Use RSpec as testing framework
- **Coverage**: Aim for high test coverage

## Zeitwerk Configuration

Current configuration in `lib/factorix.rb`:

```ruby
loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/factorix/version.rb")
loader.ignore("#{__dir__}/factorix/errors.rb")
loader.inflector.inflect(
  "api" => "API",
  "api_credential" => "APICredential",
  "http" => "HTTP",
  "mac_os" => "MacOS",
  "mod_download_api" => "MODDownloadAPI",
  "mod_info" => "MODInfo",
  "mod_list_api" => "MODListAPI",
  "mod_version" => "MODVersion",
  "wsl" => "WSL"
)
loader.setup
```

## Related Documentation

- [Architecture](architecture.md)
- [Technology Stack](technology-stack.md)
- [Component Details](components/)

---

**Legend:**
- `[ ]` Not started
- `[x]` Completed
- ⭐ Recommended starting point
