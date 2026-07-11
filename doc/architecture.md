# Architecture

## Dependency Injection

Plain constructor injection: the composition root (`internal/app.App`) builds
each dependency once and passes it explicitly; there is no DI container.
Expensive components (API clients, caches) are built lazily via
`sync.OnceValues` so commands that don't need them never pay for
construction.

## Package Structure

```
cmd/factorix/          # main package — CLI entry point
internal/
├── api/                # MOD Portal / game download API clients and data types
├── app/                # Composition root (config, runtime, logger, caches, API clients)
├── blueprint/          # Blueprint string encode/decode (base64 + zlib + JSON)
├── cache/              # Cache interface + filesystem backend
├── changelog/          # Factorio changelog.txt parsing and manipulation
├── cli/                # cobra command definitions
├── config/             # Config struct + TOML loading
├── dependency/         # Dependency parsing, graph, validation
├── httpx/              # HTTP client with retry/cache decorators
├── logging/            # slog setup (file handler, level parsing)
├── mod/                # Core domain: MOD, MODList, MODState, MODVersion, etc.
├── platform/           # Platform abstraction (Linux, macOS, Windows, WSL)
├── progress/           # mpb-based progress bar rendering
├── rcon/               # Source RCON protocol client
├── save/               # Save file (level.dat) parsing
├── serdes/             # Binary serialization for Factorio's property tree format
├── settings/           # mod-settings.dat binary + JSON round trip
└── transfer/           # File download/upload with progress and digest verification
```

`internal/httpx` and `internal/platform` are named to avoid shadowing the
stdlib `http` and `runtime` packages (`platform` imports stdlib `runtime`).

See each package's Go doc comments for details (`go doc ./internal/<pkg>`).

## Technology Stack

- **[cobra](https://github.com/spf13/cobra)** - CLI framework
- **[BurntSushi/toml](https://github.com/BurntSushi/toml)** - Configuration file parsing
- **[avast/retry-go](https://github.com/avast/retry-go)** - Retry logic for network operations
- **[vbauerster/mpb](https://github.com/vbauerster/mpb)** - Progress display with multi-bar support
- **[fatih/color](https://github.com/fatih/color)** - Terminal text coloring
- **[gofrs/flock](https://github.com/gofrs/flock)** - Cross-process file locking
- **`log/slog`** (stdlib) - Logging
- **`archive/zip`**, **`compress/zlib`**, **`encoding/binary`** (stdlib) - Factorio file format handling
- **golangci-lint** (bundling staticcheck) - Linting
- **goreleaser** - Multi-platform release builds

## Related Documentation

- [Project Overview](overview.md)
