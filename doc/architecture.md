# Architecture

## Dependency Injection

Plain constructor injection: classes take dependencies as keyword arguments
whose defaults resolve from the `Factorix::Application` composition root
(`Factorix.app`).

See [application.md](components/application.md) for the composition root and its components.

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
├── Application        # Composition root
└── Domain objects     # MOD, MODList, MODSettings, InstalledMOD, etc.
```

See [components/](components/) for detailed documentation of each module.

## Technology Stack

### Runtime Dependencies

- **Zeitwerk** - Auto-loading
- **dry-cli** - CLI framework
- **perfect_toml** - Configuration file parsing
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
