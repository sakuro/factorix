# Architecture

## Design Principles

### Dependency Injection (DI)
- Use dry-auto_inject to make dependencies injectable
- Main injection targets:
  - Logger
  - Cache management
  - Other common services

### Naming Conventions
- MOD is always uppercase (not Mod but **MOD**)
- Must specify `"mod" => "MOD"` in Zeitwerk configuration

## Class Hierarchy

```
Factorix/
├── CLI
│   └── Commands/
│       ├── Version              # Display Factorix version
│       ├── Path                 # Display paths
│       ├── Launch               # Launch Factorio
│       └── MOD/
│           ├── Check            # Validate dependencies
│           ├── Disable          # Disable MODs with dependents
│           ├── Download         # Download MOD files
│           ├── Edit             # Edit MOD metadata
│           ├── Enable           # Enable MODs with dependencies
│           ├── Install          # Download and enable MODs
│           ├── List             # List installed MODs
│           ├── Search           # Search MODs on Portal
│           ├── Sync             # Sync from save file
│           ├── Uninstall        # Remove MODs from disk
│           ├── Update           # Update MODs to latest versions
│           ├── Upload           # Upload MODs to portal
│           ├── Image/
│           │   ├── Add          # Add image to MOD
│           │   ├── Edit         # Edit MOD images
│           │   └── List         # List MOD images
│           └── Settings/
│               ├── Dump         # Export settings to JSON
│               └── Restore      # Import settings from JSON
│
├── API/
│   ├── MODPortalAPI           # List/search/full MOD info (no auth)
│   ├── MODDownloadAPI         # Download MODs (username + token)
│   ├── MODManagementAPI       # Upload/edit MODs (API key)
│   ├── MODInfo                # Unified info for all API endpoints
│   ├── Release                # MOD release info
│   ├── Image                  # MOD screenshot/image
│   ├── License                # License info
│   ├── Category               # MOD category (flyweight pattern)
│   └── Tag                    # MOD tags (flyweight pattern)
│
├── Portal                     # Object-oriented wrapper for API
│
├── MODVersion                 # MOD version (major.minor.patch)
├── GameVersion                # Game version (major.minor.patch-build)
├── InfoJSON                   # info.json metadata
│
├── HTTP/                      # HTTP layer with decorators
│   ├── Client                 # Base HTTP client (Net::HTTP wrapper)
│   ├── Response               # HTTP response wrapper
│   ├── CachedResponse         # Cached response wrapper
│   ├── RetryDecorator         # Automatic retry decorator
│   ├── CacheDecorator         # Caching decorator
│   └── RetryStrategy          # Retry configuration
│
├── Cache/
│   └── FileSystem             # Initial implementation
│
├── SerDes/
│   ├── Serializer
│   ├── Deserializer
│   ├── SignedInteger          # Signed 64-bit integer
│   └── UnsignedInteger        # Unsigned 64-bit integer
│
├── Runtime/                   # Runtime environment abstraction
│   ├── Base                   # Abstract base class
│   ├── Linux
│   ├── MacOS
│   ├── Windows
│   └── WSL
│
├── Progress/
│   ├── Presenter              # Single progress presenter (wraps TTY::ProgressBar)
│   ├── PresenterAdapter       # Adapter for TTY::ProgressBar compatibility
│   ├── MultiPresenter         # Multi-progress presenter (returns PresenterAdapter)
│   ├── DownloadHandler        # Event handler for download progress
│   ├── UploadHandler          # Event handler for upload progress
│   └── ScanHandler            # Event handler for scan progress
│
├── MOD                        # Data.define - local MOD representation
├── MODList                    # mod-list.json management
├── MODSettings                # mod-settings.dat management
├── MODState                   # Data.define - MOD state (enabled/disabled)
├── InstalledMOD               # Data.define - installed MOD with metadata
├── SaveFile                   # Data.define - save file information
│
├── Dependency/                # Dependency resolution system
│   ├── MODVersionRequirement  # Version requirement
│   ├── Entry                  # Data.define - single dependency entry
│   ├── Parser                 # Parslet-based dependency string parser
│   ├── List                   # Collection of dependencies
│   ├── Graph                  # Dependency graph (DAG with TSort)
│   │   └── Builder            # Graph builder from installed MODs
│   ├── Node                   # Graph node representation
│   ├── Edge                   # Graph edge representation
│   ├── Validator              # Dependency validator
│   └── ValidationResult       # Validation result with errors
│
├── ServiceCredential          # username + token (for MOD downloads)
├── APICredential              # api_key (for Portal API)
├── Application                # dry-container + dry-configurable
│
└── Error                      # Simple error hierarchy
```

## Zeitwerk Configuration

```ruby
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "mod" => "MOD",              # ★Important
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

## File Name to Class Name Mapping Examples

- `mod.rb` → `Factorix::MOD`
- `mod_list.rb` → `Factorix::MODList`
- `mod_version.rb` → `Factorix::MODVersion`
- `game_version.rb` → `Factorix::GameVersion`
- `info_json.rb` → `Factorix::InfoJSON`
- `api/mod_info.rb` → `Factorix::API::MODInfo` (with nested `MODInfo::Detail`)
- `api/category.rb` → `Factorix::API::Category`
- `api/release.rb` → `Factorix::API::Release`
- `api/image.rb` → `Factorix::API::Image`
- `api/license.rb` → `Factorix::API::License`
- `api/tag.rb` → `Factorix::API::Tag`
- `api/mod_portal_api.rb` → `Factorix::API::MODPortalAPI`
- `api/mod_download_api.rb` → `Factorix::API::MODDownloadAPI`
- `portal.rb` → `Factorix::Portal`
- `dependency/mod_version_requirement.rb` → `Factorix::Dependency::MODVersionRequirement`
- `ser_des/signed_integer.rb` → `Factorix::SerDes::SignedInteger`
- `ser_des/unsigned_integer.rb` → `Factorix::SerDes::UnsignedInteger`
- `transfer/downloader.rb` → `Factorix::Transfer::Downloader`
- `transfer/uploader.rb` → `Factorix::Transfer::Uploader`
- `http/retry_strategy.rb` → `Factorix::HTTP::RetryStrategy`

## Related Documentation

- [Project Overview](overview.md)
- [Technology Stack](technology-stack.md)
- [Component Details](components/)
