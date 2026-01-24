## [Unreleased]

### Changed

- Refactor `Cache::FileSystem` to use `cache_type:` parameter instead of `root:` (#25)
  - Aligns interface with `Cache::Redis` for consistent backend initialization
  - Cache directory is now auto-computed from `Container[:runtime].factorix_cache_dir / cache_type`

### Added

- Add S3 cache backend (`Cache::S3`) for cloud-native deployments (#18)
  - Optional dependency: requires `aws-sdk-s3` gem in user's Gemfile
  - Configure with `config.cache.<type>.backend = :s3`
  - Distributed locking via conditional PUT (`if_none_match: "*"`)
  - TTL managed via S3 custom metadata, age from native `Last-Modified`

- Add Redis cache backend (`Cache::Redis`) with distributed locking support (#19)
  - Optional dependency: requires `redis` gem (~> 5) in user's Gemfile
  - Configure with `config.cache.<type>.backend = :redis`
  - Supports distributed locking via Lua script for atomic lock release
  - Auto-namespaced keys: `factorix-cache:{cache_type}:{key}`

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
