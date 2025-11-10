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
│       ├── Info
│       ├── Launch
│       └── MOD/
│           ├── List
│           ├── Enable
│           ├── Disable
│           ├── Download
│           ├── Install
│           ├── Uninstall
│           ├── Publish          # First time: publish API, subsequent: upload API
│           ├── Edit             # Edit MOD details (title, summary, description, etc.)
│           ├── Image/
│           │   ├── List         # List MOD images with IDs
│           │   ├── Add          # Add MOD images
│           │   └── Edit         # Edit MOD image order
│           └── Settings/
│               ├── Load
│               └── Dump
│
├── API/
│   ├── PublicAPI              # No authentication required
│   ├── DownloadAPI            # username + token
│   └── PortalAPI              # API key
│
├── Portal                     # Object-oriented wrapper for API
│
├── Types/                     # Value objects using Data.define
│   ├── MODInfo                # Unified info for all API endpoints (list/Short/Full)
│   │   └── Detail             # Nested class for Full API-specific fields
│   ├── Release                # MOD release info (with URI conversion)
│   ├── Image                  # MOD screenshot/image (used in Detail)
│   ├── License                # License info (used in Detail)
│   ├── Category               # MOD category (flyweight pattern)
│   ├── MODVersion             # MOD version (major.minor.patch)
│   ├── GameVersion            # Game version (major.minor.patch-build)
│   ├── MODList                # List container (deferred)
│   ├── Pagination             # (not implemented - API returns all results)
│   └── PaginationLinks        # (not implemented - API returns all results)
│
├── Transfer/                  # File transfer
│   ├── RetryStrategy          # Wrapper for retriable gem
│   ├── HTTP                   # net/http wrapper (resume, progress notification)
│   ├── Downloader             # Uses Transfer::HTTP
│   └── Uploader               # Uses Transfer::HTTP
│
├── Cache/
│   └── FileSystem             # Initial implementation
│
├── SerDes/
│   ├── Serializer
│   ├── Deserializer
│   ├── GameVersion            # Formerly Version64: for game/file format
│   └── MODVersion             # Formerly Version24: for MODs
│
├── Runtime/                   # Runtime environment abstraction
│   ├── Base                   # Abstract base class
│   ├── Linux
│   ├── MacOS
│   ├── Windows
│   └── WSL
│
├── Progress/
│   ├── Base                   # Progress notification base class
│   └── Bar                    # ruby-progressbar implementation (subclass of Progress::Base)
│
├── MOD                        # Data.define - local MOD
├── MODList                    # mod-list.json management
├── MODSettings                # mod-settings.dat management
├── MODState
├── MODDependency              # Data.define - single dependency
├── MODDependencyParser        # Parser for dependency strings
├── MODDependencies            # Manages all dependencies of a MOD
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
- `types/mod_info.rb` → `Factorix::Types::MODInfo` (with nested `MODInfo::Detail`)
- `types/mod_version.rb` → `Factorix::Types::MODVersion`
- `types/game_version.rb` → `Factorix::Types::GameVersion`
- `types/category.rb` → `Factorix::Types::Category`
- `types/release.rb` → `Factorix::Types::Release`
- `types/image.rb` → `Factorix::Types::Image`
- `types/license.rb` → `Factorix::Types::License`
- `api/mod_portal_api.rb` → `Factorix::API::MODPortalAPI`
- `api/mod_download_api.rb` → `Factorix::API::MODDownloadAPI`
- `portal.rb` → `Factorix::Portal`
- `transfer/retry_strategy.rb` → `Factorix::Transfer::RetryStrategy`
- `transfer/http.rb` → `Factorix::Transfer::HTTP`
- `ser_des/game_version.rb` → `Factorix::SerDes::GameVersion`
- `ser_des/mod_version.rb` → `Factorix::SerDes::MODVersion`

## Related Documentation

- [Project Overview](overview.md)
- [Technology Stack](technology-stack.md)
- [Component Details](components/)
