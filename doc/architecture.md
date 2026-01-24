# Architecture

## Dependency Injection

Uses dry-auto_inject for dependency injection:
- Logger
- Cache backends
- HTTP clients
- API clients

See [container.md](components/container.md) for registered services.

## Module Structure

```
Factorix/
├── CLI::Commands/     # CLI commands (dry-cli)
├── API/               # MOD Portal API clients and data objects
├── Portal             # High-level API wrapper
├── HTTP/              # HTTP client with decorator pattern
├── Cache/             # Multi-backend cache (FileSystem, Redis, S3)
├── Transfer/          # File download/upload with progress
├── Runtime/           # Platform abstraction (Linux, macOS, Windows, WSL)
├── Dependency/        # Dependency resolution (DAG with TSort)
├── SerDes/            # Binary serialization for Factorio formats
├── Progress/          # Progress bar presenters and handlers
├── Container          # DI container (dry-container)
└── Domain objects     # MOD, MODList, MODSettings, InstalledMOD, etc.
```

See [components/](components/) for detailed documentation of each module.

## Technology Stack

### Runtime Dependencies

- **Zeitwerk** - Auto-loading
- **dry-cli** - CLI framework
- **dry-core** - Dependency container
- **dry-auto_inject** - Dependency injection
- **dry-configurable** - Configuration management
- **dry-events** - Event system for progress notification
- **dry-logger** - Logging
- **retriable** - Retry logic for network operations
- **tty-progressbar** - Progress display with multi-bar support
- **tint_me** - Terminal text coloring
- **parslet** - PEG parser for dependency string parsing
- **rubyzip** - ZIP file handling
- **concurrent-ruby** - Parallel processing

### Development Tools

- **RSpec** / **WebMock** / **SimpleCov** - Testing
- **RuboCop** - Code style
- **Steep** / **RBS** - Type checking
- **YARD** - Documentation

## Related Documentation

- [Project Overview](overview.md)
- [Component Details](components/)
