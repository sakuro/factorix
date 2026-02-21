## [Unreleased]

### Changed

- Refactor `License` to use flyweight pattern for standard licenses with `.for(id)` method
- Add `.identifiers` class method to `Category`, `License`, and `Tag`
- Replace `License.identifier_values` with `License.identifiers`

## [0.9.1] - 2026-02-20

### Added

- Add `mod changelog extract` command to extract a specific version's changelog section

## [0.9.0] - 2026-02-20

### Added

- Add `mod changelog add` command to add entries to MOD changelog
- Add `mod changelog check` command to validate MOD changelog structure
- Add `mod changelog release` command to convert Unreleased section to a versioned section

## [0.8.1] - 2026-02-17

### Added

- Add `tsort` as explicit dependency for Ruby 4.1 compatibility (#55)

### Removed

- Remove `irb` from development dependencies

### Fixed

- Fix documentation to clarify that ServiceCredential is required for MOD downloads from the portal

## [0.8.0] - 2026-02-03

### Added

- Add `download` command to download Factorio game files from the official Download API (#51)
  - Supports alpha, expansion, demo, and headless builds
  - Auto-detects platform (Windows, Linux, macOS, WSL)
  - Resolves latest version from stable/experimental channels
- Add `head` method to HTTP client and decorators (`Client`, `RetryDecorator`, `CacheDecorator`)

## [0.7.0] - 2026-01-24

### Added

- Add pluggable cache backend architecture with Redis and S3 support (#18, #19)
  - Configure backend per cache type: `config.cache.<type>.backend = :file_system | :redis | :s3`
  - **Redis backend** (`Cache::Redis`): requires `redis` gem (~> 5)
    - Distributed locking via Lua script for atomic lock release
    - Auto-namespaced keys: `factorix-cache:{cache_type}:{key}`
  - **S3 backend** (`Cache::S3`): requires `aws-sdk-s3` gem
    - Distributed locking via conditional PUT (`if_none_match: "*"`)
    - TTL managed via S3 custom metadata, age from native `Last-Modified`
  - `cache stat` command displays backend-specific information (directory, URL, bucket, etc.)

### Changed

- Refactor `Cache::FileSystem` to use `cache_type:` parameter instead of `root:` (#25)
  - Aligns interface with other backends for consistent initialization
  - Cache directory is now auto-computed from `Container[:runtime].factorix_cache_dir / cache_type`

### Removed

- Remove deprecated `Factorix::Application` compatibility class
  - Use `Factorix::Container` for DI (`[]`, `resolve`, `register`)
  - Use `Factorix.config` and `Factorix.configure` for configuration

## [0.6.0] - 2026-01-18

### Changed

- Reorganize configuration and DI container interfaces (#7, #9)
  - `Factorix::Application` renamed to `Factorix::Container` (DI container only)
  - Configuration interface (`config`, `configure`, `load_config`) moved to `Factorix` module
  - Use `Factorix.configure { |c| ... }` instead of `Factorix::Container.configure { |c| ... }`

### Fixed

- Fix integer CLI options being parsed as strings after dry-cli 1.4.0 update (#12)

### Deprecated

- `Factorix::Application` still works but emits deprecation warnings; will be removed in v1.0
  - DI methods (`[]`, `resolve`, `register`) delegate to `Factorix::Container`
  - Configuration methods (`config`, `configure`) delegate to `Factorix`

## [0.5.1] - 2026-01-13

### Fixed

- Fix `completion` command failing without arguments after dry-cli 1.4.0 update (#4)

## [0.5.0] - 2025-12-26

### Added

- **CLI tool** for Factorio MOD management, settings sync, and game control
- **MOD management commands**: installation, lifecycle, dependency validation
- **MOD Portal integration**: download, upload, metadata/image management
- **Utility commands**: version display, path info, game launch, shell completion
- **Cache management**: statistics and eviction
- **Dependency resolution** with graph-based analysis and incompatibility detection
- **Settings management**: export/import mod-settings.dat as JSON
- **Save file analysis**: extract MOD information and startup settings
- **Multi-platform support**: Linux (native and WSL), macOS, and Windows

For detailed documentation, see:
- [Project Overview](doc/overview.md)
- [CLI Commands](doc/components/cli.md)
- [Architecture](doc/architecture.md)
