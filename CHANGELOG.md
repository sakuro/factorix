## [Unreleased]

### Changed

- Rename `Factorix::Application` to `Factorix::Container` to avoid naming conflicts when used as a library (#7)

### Deprecated

- `Factorix::Application` still works but emits a deprecation warning; will be removed in v1.0

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
