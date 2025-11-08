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
- [x] `ser_des/game_version.rb` - 64-bit game version format (4 × u16)
  - [x] String parsing ("1.2.3-4" or "1.2.3")
  - [x] Integer tuple construction
  - [x] Comparable support
  - [x] `to_s`, `to_a` methods
- [x] `ser_des/mod_version.rb` - 24-bit MOD version format (3 × u8)
  - [x] String parsing ("1.2.3")
  - [x] Integer tuple construction
  - [x] Comparable support
  - [x] `to_s`, `to_a` methods
- [x] Tests: `spec/factorix/ser_des/**/*_spec.rb`
  - [x] 128 examples, 0 failures
  - [x] Line Coverage: 92.66% (202/218)
  - [x] Branch Coverage: 85.71% (54/63)
  - [x] Boundary value tests (255 for space-optimized)
  - [x] Multibyte UTF-8 string tests
  - [x] Encoding validation tests
- [x] Zeitwerk inflection: `"mod_version" => "MODVersion"`

**Reference**: `factorix.old/lib/factorix/ser_des/`

**Dependencies**: Errors (UnknownPropertyType)

## Phase 2: Authentication & Configuration

### 2.1 Credentials

Authentication credentials for API access.

- [ ] `service_credential.rb` - username + token (MOD downloads)
  - [ ] Load from `player-data.json` via Runtime
  - [ ] Load from environment variables
  - [ ] Integration with mise/.env
- [ ] `api_credential.rb` - API key (Portal API)
  - [ ] Load from environment variables
  - [ ] Integration with mise/.env
- [ ] Tests: `spec/factorix/service_credential_spec.rb`
- [ ] Tests: `spec/factorix/api_credential_spec.rb`

**Dependencies**: Runtime

### 2.2 Application

DI container and configuration management.

- [ ] `application.rb` - dry-container + dry-configurable
  - [ ] Configuration settings (cache_dir, config_dir, log_level, http timeouts)
  - [ ] Container registration (cache, logger, retry_strategy, credentials)
  - [ ] Load configuration from `$XDG_CONFIG_HOME/factorix/config.rb`
- [ ] `Import = Dry::AutoInject(Factorix::Application)` for DI
- [ ] Tests: `spec/factorix/application_spec.rb`

**Dependencies**: Runtime, Credentials

## Phase 3: External Communication (Low-level)

HTTP communication layer that works with raw Hash data.

### 3.1 Transfer

File transfer with retry and progress notification.

- [ ] `transfer/retry_strategy.rb` - Wrapper for retriable gem
  - [ ] Exponential backoff configuration
  - [ ] Retry conditions (network errors, timeouts)
- [ ] `transfer/http.rb` - net/http wrapper
  - [ ] Resume support for downloads
  - [ ] Progress notification hooks
  - [ ] Timeout configuration
- [ ] `transfer/downloader.rb` - File download with caching
- [ ] `transfer/uploader.rb` - File upload (multipart/form-data)
- [ ] `progress/base.rb` - Progress notification base class
- [ ] `progress/bar.rb` - ruby-progressbar implementation
- [ ] Tests: `spec/factorix/transfer/**/*_spec.rb`
- [ ] Tests: Use WebMock for HTTP stubbing

**Dependencies**: None (standalone)

### 3.2 API Layer

Low-level API wrappers returning Hash (parsed JSON).

- [ ] `api/public_api.rb` - Public endpoints (no auth)
  - [ ] `GET /api/mods` - List MODs with pagination
  - [ ] `GET /api/mods/{name}` - Basic MOD info
  - [ ] `GET /api/mods/{name}/full` - Full MOD info with dependencies
- [ ] `api/download_api.rb` - Download endpoints (username + token)
  - [ ] Download MOD files with authentication
- [ ] `api/portal_api.rb` - Portal management (API key)
  - [ ] `POST /v2/mods/init_upload` - Initialize upload
  - [ ] `POST /v2/mods/init_publish` - Initialize publish
  - [ ] `POST /v2/mods/edit_details` - Edit MOD details
  - [ ] `POST /v2/mods/images/add` - Add images
  - [ ] `POST /v2/mods/images/edit` - Edit image order
- [ ] Tests: `spec/factorix/api/**/*_spec.rb`
- [ ] Tests: Use WebMock to stub API responses
- [ ] Error handling (4xx, 5xx, network, SSL, JSON parsing)

**Reference**: Test actual API responses to inform Types design

**Dependencies**: Transfer, Credentials

## Phase 4: Data Models (High-level)

Immutable value objects based on actual API responses.

### 4.1 Types

Value objects using Data.define (Ruby 3.2+).

- [ ] `types/pagination.rb` - Pagination metadata
- [ ] `types/pagination_links.rb` - Pagination links (first, prev, next, last)
- [ ] `types/license.rb` - License information
- [ ] `types/release.rb` - MOD release information
  - [ ] Design based on actual API responses from Phase 3.2
  - [ ] Handle `info_json` with/without dependencies
- [ ] `types/mod_list_entry.rb` - Entry from `/api/mods`
- [ ] `types/mod_info.rb` - Basic info from `/api/mods/{name}`
- [ ] `types/mod_info_with_deps.rb` - Full info from `/api/mods/{name}/full`
- [ ] `types/mod_list.rb` - List with pagination
- [ ] Tests: `spec/factorix/types/**/*_spec.rb`

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

### 4.3 Portal

High-level API wrapper converting Hash to Types.

- [ ] `portal.rb` - Object-oriented API wrapper
  - [ ] `#list_mods` → `Types::MODList`
  - [ ] `#get_mod_info(name)` → `Types::MODInfo`
  - [ ] `#get_mod_full(name)` → `Types::MODInfoWithDeps`
  - [ ] `#download_mod(name, version)`
  - [ ] `#upload_mod(file)`
  - [ ] `#publish_mod(file, options)`
  - [ ] `#edit_mod_details(name, details)`
  - [ ] `#add_mod_images(name, images)`
  - [ ] `#edit_mod_images(name, image_ids)`
- [ ] Hash → Types conversion logic
- [ ] Business logic (if any)
- [ ] Tests: `spec/factorix/portal_spec.rb`

**Dependencies**: API, Types, MODDependencies

## Phase 5: Storage Layer

Local file and cache management.

### 5.1 Cache

File-based caching for downloads.

- [ ] `cache/file_system.rb` - Initial implementation
  - [ ] Key-value storage in `Runtime#xdg_cache_home_dir`
  - [ ] TTL support
  - [ ] Size limits
- [ ] Tests: `spec/factorix/cache/**/*_spec.rb`

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

Configure at the start of Phase 1:

```ruby
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "mod" => "MOD",
  "api" => "API",
  "cli" => "CLI",
  "http" => "HTTP",
  "mac_os" => "MacOS",
  "wsl" => "WSL"
)
loader.ignore("#{__dir__}/factorix/errors.rb")
loader.ignore("#{__dir__}/factorix/version.rb")
loader.setup
loader.eager_load
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
