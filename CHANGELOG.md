## [Unreleased]

## [0.21.0] - 2026-07-13

### Added

- Accept Factorio 2.1 as a `mod search --version` filter value
- Recognize `recycler` as an official expansion MOD alongside `space-age`, `quality`, and `elevated-rails` (#169)
- Add `mod license list` and `mod license show <id>` to look up standard MOD Portal license identifiers and their license text URLs (#166)

### Fixed

- Size download progress bars to the actual terminal width instead of a fixed 40 columns

## [0.20.0] - 2026-07-12

Factorix is being rewritten from Ruby to Go, reaching full command parity:
every command works the same way, but the distributed artifact becomes a
single, self-contained binary — no Ruby, Bundler, or gem install required.

### Added

- Add `rcon exec` and `rcon eval` commands to execute a console command or evaluate a Lua script on a running Factorio server via RCon
- Add PowerShell completion support
- Recognize recommended (`+` prefix) dependencies across `mod show`, `mod install`, `mod enable`, `mod sync`, and `mod check`: `mod show` lists them in a dedicated section, `mod install`/`mod enable`/`mod sync` resolve and enable them automatically like required dependencies, and `mod check` warns when one is installed but disabled; opt out with `--ignore-recommended`

### Changed

- **BREAKING**: The configuration file format is now TOML (`~/.config/factorix/config.toml`); the Ruby DSL (`config.rb`) is no longer read
- **BREAKING**: `factorix completion` now generates each shell's script on demand instead of shipping static files under `completion/`; run `factorix completion <shell>` (or `eval "$(factorix completion zsh)"`) instead of sourcing the old files, which no longer exist
- Suppress the progress bar when the output stream is not a TTY, and honor the `NO_COLOR` convention
- Distribute as prebuilt binaries for Linux, macOS, and Windows instead of a RubyGems package

### Removed

- Drop the Redis and S3 cache backends; only the filesystem cache remains

## [0.12.0] - 2026-04-21

### Added

- Add `--strict-version` flag to `mod sync` to install exact MOD versions from the save file (#75)

### Changed

- Raise minimum Ruby version requirement to 3.3 (#81)
- `mod show` always displays both Latest Version and Installed Version when a MOD is installed; "(update available)" is appended only when the local version is outdated (#82)
- Add `--json` option to `mod show` for machine-readable output (#83)

## [0.11.1] - 2026-03-03

### Fixed

- Fix `mod sync` incorrectly saving `mod-list.json` and `mod-settings.dat` when nothing changed (#74)
- Include startup settings changes in the `mod sync` plan and confirmation flow (#74)

## [0.11.0] - 2026-03-03

### Added

- Add `blueprint decode` command to decode Factorio blueprint strings to JSON (#76)
- Add `blueprint encode` command to encode JSON to Factorio blueprint strings (#76)

### Changed

- `mod sync` now disables enabled MODs (including expansion MODs) not listed in the save file by default (#70)
- Add `--keep-unlisted` option to `mod sync` to preserve MODs not listed in the save file (#70)

## [0.10.0] - 2026-02-21

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
