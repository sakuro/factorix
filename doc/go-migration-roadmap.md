# Go Migration Roadmap

## Overview

This document describes a phased plan for porting Factorix from Ruby to Go.
The goal is a self-contained single binary that supports Linux, macOS, and Windows —
not a line-by-line translation, but a Go-idiomatic reimplementation with
command-level feature parity (except the items listed in Out of Scope).

**Repository strategy:** the Go implementation lives in this repository
(module path `github.com/sakuro/factorix`), developed on a long-lived
`go-rewrite` branch that serves as the temporary trunk. `main` stays Ruby until
the port reaches command parity (Phase 10), then is replaced by the branch.
Sequencing:

1. Ruby development is frozen on `main` at the e2e-suite merge. The dry-*
   simplification (Stages 1–4) lives only on `go-rewrite`, so the gem line
   never ships the TOML config break. Emergency gem fixes branch from `main`
   (tagged `ruby-vX.Y.Z` to avoid colliding with Go release tags).
2. Go development proceeds on `go-rewrite`. The Ruby sources stay on the branch
   during development — the trees do not overlap (`lib/` vs `cmd/`, `internal/`)
   and keeping them enables Ruby-vs-Go parity testing against the same fixtures.
   Pull requests during this period target `go-rewrite`, not `main`.
3. At parity, `main` is replaced, Ruby sources are removed (history retains
   them), and goreleaser tags continue the gem's `vX.Y.Z` sequence — reaching
   parity is the `v1.0.0` milestone.

**Prerequisite work in the Ruby repository:** the
[dry-* simplification plan](dry-simplification-plan.md) — DI container →
constructor injection, dry-events → callbacks, dry-configurable → plain config
with a TOML file, dry-logger → stdlib Logger. This validates the Go design
decisions below in the existing codebase and keeps the two implementations
structurally close during the port. Gems with direct Go equivalents (rubyzip,
retriable, tty-progressbar, concurrent-ruby) need no pre-work.

---

## Design Decisions (Ruby → Go Mapping)

### Type System

| Ruby | Go |
|------|----|
| Duck typing | Explicit interfaces |
| `nil / bool / Float / String / Array / Hash` (PropertyTree) | `PropertyTree` struct with `Kind` field (see Key Technical Challenges) |
| `Data.define` value objects | Immutable structs |
| `Comparable` mixin | Custom `Less`/`Equal` methods |
| `Enumerable` mixin | Iterator pattern with `func(yield func(T) bool)` (Go 1.23 range-over-func) |

The minimum Go version is **1.23** (range-over-func); declare it in `go.mod`.

### Error Handling

Ruby exceptions become explicit `(T, error)` return values.
Define sentinel errors and custom error types in a single `errors.go` per package.

```
Factorix::Error              → type Error struct { ... }
Factorix::FileFormatError    → type FileFormatError struct { Path string }
Factorix::UnsupportedPlatformError → type UnsupportedPlatformError struct { ... }
```

### Context Propagation

All I/O-performing APIs (HTTP, cache, downloader, uploader, RCON) take
`ctx context.Context` as their first parameter. This is decided up front because
retrofitting `ctx` reshapes every interface in the HTTP/cache/transfer layers.
Cancellation (Ctrl-C) is wired once in `main.go` via `signal.NotifyContext`.

### Dependency Injection

Eliminate the DI container (dry-core `Container` + dry-auto_inject).
Use plain constructor injection — pass dependencies as struct fields.
For wiring the application entry point, manual `main.go` setup is sufficient at this scale.

The Ruby container's decorator chains carry over as plain composition:

```
API client:  Client → CacheTransport → Retry
Download:    Client → Retry           (cache handled by Downloader)
Upload:      Client → Retry           (no cache)
```

### Events / Progress

Replace dry-events pub/sub with callback interfaces.

```go
type ProgressListener interface {
    OnStart(total int64)
    OnProgress(downloaded int64)
    OnFinish()
}
```

Pass `nil` where progress reporting is not needed. The one non-progress use of
dry-events — `MODManagementAPI` notifying `MODPortalAPI` to invalidate its cache
after upload/edit — becomes an explicit callback field on the management client.

### Logging

stdlib `log/slog`, writing to the same platform-dependent log file path as the
Ruby version. The `log_level` setting is preserved.

### Concurrency

Replace concurrent-ruby with goroutines and `errgroup`.

### Configuration

A plain config struct (`internal/config`) loaded from `config.toml`, plus
environment variables. The Ruby version adopts the same TOML file in the
dry-* simplification plan, so user config files carry over unchanged.
Settings: `log_level`, runtime path overrides
(`executable_path` / `user_dir` / `data_dir`), RCON (`host` / `port` / `password`),
HTTP timeouts, and per-cache-type settings (`ttl`, `max_file_size`,
`compression_threshold`).

### Cache Backends

Define a `Cache` interface; implement only the filesystem backend.
The Ruby Redis and S3 backends are intentionally dropped (see Out of Scope).
The three cache types (download / api / info_json) and their differing
TTL/compression defaults carry over.

### Platform Detection

Replace `RUBY_PLATFORM` regex with `runtime.GOOS`, plus `/proc/version` for WSL.
The Ruby `UserConfigurable` path overrides map to the config settings above.

---

## Recommended Libraries

| Purpose | Library |
|---------|---------|
| CLI framework | [cobra](https://github.com/spf13/cobra) |
| HTTP client | `net/http` (stdlib) |
| ZIP handling | `archive/zip` (stdlib) |
| Binary encoding | `encoding/binary` (stdlib) |
| zlib (saves, blueprints) | `compress/zlib` (stdlib) |
| Logging | `log/slog` (stdlib) |
| Progress bar | [mpb](https://github.com/vbauerster/mpb) (multi-bar, matches parallel downloads) |
| Dependency parsing | hand-rolled recursive descent (see Key Technical Challenges) |
| Terminal colors | [fatih/color](https://github.com/fatih/color) |
| Config file | [BurntSushi/toml](https://github.com/BurntSushi/toml) |
| Retry logic | [avast/retry-go](https://github.com/avast/retry-go) |
| RCON | [gorcon/rcon](https://github.com/gorcon/rcon) (supports Factorio) |
| Release tooling | [goreleaser](https://goreleaser.com/) |
| Testing | `testing` + [testify](https://github.com/stretchr/testify) |

`internal/httpx` and `internal/platform` are named to avoid shadowing the stdlib
`http` and `runtime` packages (`platform` must import stdlib `runtime`).

---

## Directory Structure

```
factorix/                  # repository root (Ruby lib/ and spec/ coexist until the main swap)
├── cmd/factorix/          # main package — CLI entry point
│   └── main.go
├── internal/
│   ├── api/               # MOD Portal / game download API clients and data types
│   ├── blueprint/         # Blueprint string encode/decode (base64 + zlib + JSON)
│   ├── cache/             # Cache interface + filesystem backend
│   ├── changelog/         # Factorio changelog.txt parsing and manipulation
│   ├── cli/               # cobra command definitions
│   ├── config/            # Config struct + TOML loading
│   ├── dependency/        # Dependency parsing, graph, validation
│   ├── httpx/             # HTTP client with retry/cache decorators
│   ├── mod/               # Core domain: MOD, MODList, MODState, save file, etc.
│   ├── platform/          # OS detection and path resolution
│   ├── portal/            # High-level API facade
│   ├── progress/          # Progress listener interfaces and implementations
│   ├── serdes/            # Binary serializer/deserializer (Factorio format)
│   ├── settings/          # MOD settings (mod-settings.dat)
│   └── transfer/          # Downloader / Uploader
├── go.mod                 # module github.com/sakuro/factorix, go 1.23
├── go.sum
└── .goreleaser.yaml
```

RCON needs no internal package — `gorcon/rcon` is used directly from the CLI layer.

---

## Phases

### Phase 0 — Project Scaffolding

**Goal:** Runnable skeleton that outputs version and help text.

- [x] Create the `go-rewrite` branch; `go mod init github.com/sakuro/factorix` (go 1.23)
- [x] `cmd/factorix/main.go` with cobra root command and `signal.NotifyContext`
- [x] cobra subcommand skeleton: `mod`, `cache`, `blueprint`, `rcon`, `completion`, `version`, `path`, `download`, `launch`, `man`
- [x] `.goreleaser.yaml` for multi-platform releases
- [x] GitHub Actions CI for the `go-rewrite` branch (build + test + `go vet`)

---

### Phase 1 — Core Domain Types

**Goal:** Stable value types used by all subsequent phases.

- [ ] `internal/mod/game_version.go` — `GameVersion` (major/minor/patch/build uint16)
- [ ] `internal/mod/mod_version.go` — `MODVersion` (major/minor/patch uint16)
  - `Less`, `Equal`, string parsing, `Stringer`
- [ ] `internal/mod/mod.go` — `MOD` struct (name, version)
- [ ] `internal/mod/mod_state.go` — `MODState` (enabled bool, version)
- [ ] `internal/mod/mod_list.go` — `MODList` (load/save `mod-list.json`, enable/disable);
      takes explicit paths — platform path resolution arrives in Phase 5
- [ ] `internal/mod/installed_mod.go` — `InstalledMOD` (path, info.json metadata)
- [ ] `internal/mod/info_json.go` — parse `info.json` inside MOD ZIP
- [ ] Error types in `internal/errors/errors.go`

---

### Phase 2 — Binary Format (SerDes)

**Goal:** Read and write Factorio's custom binary format used in save files and `mod-settings.dat`.

The Ruby implementation uses `pack`/`unpack`. In Go, use `encoding/binary` with `io.Reader`/`io.Writer`.

- [ ] `internal/serdes/deserializer.go`
  - `ReadU8`, `ReadU16`, `ReadU32`, `ReadBool`, `ReadStr`, `ReadOptimU16`, `ReadOptimU32`
  - `ReadGameVersion`, `ReadMODVersion`
  - `ReadPropertyTree` — returns `PropertyTree`
- [ ] `internal/serdes/serializer.go`
  - Symmetric write methods
- [ ] `internal/serdes/property_tree.go`
  - `PropertyTree` type with `Kind` (None/Bool/Number/String/List/Dict/SignedInt/UnsignedInt)
- [ ] Round-trip tests against the binary fixtures in `spec/fixtures`

---

### Phase 3 — Save File & MOD Settings

**Goal:** Parse `.zip` save files and `mod-settings.dat`.

- [ ] `internal/mod/save_file.go`
  - Open ZIP, locate `level.dat0` or `level-init.dat`
  - Detect and strip zlib header (CMF byte 0x78)
  - Parse save header → `GameVersion`, `[]MODState`
  - Parse startup settings → `Settings`
- [ ] `internal/settings/mod_settings.go`
  - Load / save `mod-settings.dat` (binary PropertyTree)
  - Sections: `startup`, `runtime-global`, `runtime-per-user`
  - JSON export/import (parity with Ruby `mod settings dump` / `restore`)

---

### Phase 4 — Dependency System

**Goal:** Parse dependency strings, build a DAG, validate and resolve dependencies.

The Ruby implementation uses Parslet (PEG). In Go, hand-roll a recursive descent parser.

Dependency string grammar (Factorio format; note MOD names may contain spaces):
```
dep    = [prefix " "] name [" " op " " version]
prefix = "!" | "?" | "(?)" | "~"
op     = "=" | ">" | ">=" | "<" | "<="
```

- [ ] `internal/dependency/parser.go` — parse dependency strings into `Entry` structs
- [ ] `internal/dependency/entry.go` — `Entry` (kind, name, operator, version)
- [ ] `internal/dependency/graph.go` — adjacency-list DAG
  - `AddNode`, `AddEdge`, `TopologicalSort` (Kahn's algorithm)
  - `StronglyConnectedComponents` for cycle detection
- [ ] `internal/dependency/validator.go` — validate installed MODs against requirements
- [ ] `internal/dependency/resolver.go` — determine install/uninstall order

---

### Phase 5 — Platform Abstraction & Config

**Goal:** Resolve Factorio and Factorix paths correctly on each supported OS; load configuration.

- [ ] `internal/platform/platform.go` — `Platform` interface
  ```go
  type Platform interface {
      GameDataDir() (string, error)
      GameUserDataDir() (string, error)
      ModDir() (string, error)
      // ...
  }
  ```
- [ ] `internal/platform/linux.go`, `macos.go`, `windows.go`, `wsl.go`
  - WSL detection via `/proc/version`
- [ ] `internal/platform/detect.go` — `Detect() (Platform, error)` using `runtime.GOOS`
- [ ] Config-based path overrides (Ruby `Runtime::UserConfigurable` equivalent)
- [ ] `internal/config/config.go` — config struct, TOML loading, env var overrides
- [ ] `slog` setup writing to the platform log path, honoring `log_level`

---

### Phase 6 — HTTP & Cache

**Goal:** Authenticated HTTP with caching and retry, backed by the filesystem.

- [ ] `internal/httpx/client.go` — thin wrapper around `net/http.Client`
  - HTTPS enforcement
  - Configurable connect/read/write timeouts
  - Sensitive query param masking in logs (`username`, `token`, `secure`)
- [ ] `internal/httpx/retry.go` — decorator with exponential backoff (avast/retry-go)
- [ ] `internal/cache/cache.go` — `Cache` interface (all methods take `ctx`)
- [ ] `internal/cache/filesystem.go`
  - 2-level SHA256-based directory layout
  - Optional zlib compression (per-cache-type threshold)
  - File-based locking (stale lock cleanup)
  - Metadata sidecar files (TTL, size)
- [ ] Three cache instances: download / api / info_json with differing defaults
- [ ] `internal/httpx/cache_transport.go` — `http.RoundTripper` implementing cache-aside for API calls

---

### Phase 7 — API Integration

**Goal:** Communicate with the Factorio MOD Portal and game download endpoint.

All API response types are plain structs with JSON tags.

- [ ] `internal/api/types.go` — `MODInfo`, `Release`, `Image`, `Category`, `Tag`, `License`
- [ ] `internal/api/portal.go` — `MODPortalAPI`: list, search, show
- [ ] `internal/api/download.go` — `MODDownloadAPI`: build authenticated download URL, stream to cache
- [ ] `internal/api/game_download.go` — `GameDownloadAPI`: game binary download (`download` command)
- [ ] `internal/api/management.go` — `MODManagementAPI`: upload, edit, image management
  - cache-invalidation callback to `MODPortalAPI` (replaces dry-events subscription)
- [ ] `internal/api/credential.go`
  - `ServiceCredential` — username/token from env vars or `player-data.json`
  - `APICredential` — `FACTORIO_API_KEY` (required by the management API)

---

### Phase 8 — Transfer

**Goal:** Download and upload MOD files with progress reporting.

- [ ] `internal/transfer/downloader.go`
  - Check cache → stream to cache on miss
  - SHA1 verification
  - Fire `ProgressListener` events
  - Strip auth params from cache key
  - Parallel downloads via `errgroup` + mpb multi-bar
- [ ] `internal/transfer/uploader.go`
  - Multipart form upload with progress

---

### Phase 9 — Auxiliary Domains

**Goal:** Features independent of the MOD Portal pipeline.

- [ ] `internal/blueprint/blueprint.go` — blueprint string encode/decode
  (version byte + base64 + zlib + JSON)
- [ ] `internal/changelog/changelog.go` — parse/manipulate Factorio `changelog.txt`
  (sections, categories, entry add/check/extract/release)

---

### Phase 10 — CLI Commands

**Goal:** All user-facing subcommands operational.

Implement in dependency order (domain commands before API-dependent ones).
Shared behaviors from Ruby mixins carry over as helpers: confirmation prompts
(`Confirmable`), "game must not be running" guard (`RequiresGameStopped`),
mod-list backup (`BackupSupport`).

#### Informational
- [ ] `version` — print version
- [ ] `path` — print Factorio/Factorix paths
- [ ] `completion` — generate shell completion (cobra built-in)
- [ ] `man` — man page (cobra `doc` package)

#### Local MOD Management
- [ ] `mod list` — list installed MODs
- [ ] `mod enable` / `mod disable` — recursively handle dependencies/dependents
- [ ] `mod check` — validate dependency graph
- [ ] `mod sync` — sync MOD states from a save file
- [ ] `mod settings dump` / `restore` — export/import `mod-settings.dat` (JSON)

#### MOD Author Tools
- [ ] `mod changelog add` / `check` / `extract` / `release`
- [ ] `blueprint encode` / `decode`

#### Portal-dependent
- [ ] `mod search` / `mod show`
- [ ] `mod install` / `mod uninstall` / `mod update`
- [ ] `mod download` — download without installing
- [ ] `mod upload` / `mod edit` / `mod image list/add/edit`
- [ ] `download` — download the game itself

#### Cache
- [ ] `cache stat` / `cache evict`

#### Game
- [ ] `launch` — launch Factorio (`os/exec`)
- [ ] `rcon exec` / `rcon eval` — via gorcon/rcon, using `config.rcon` settings

---

### Phase 11 — Testing & Release

**Goal:** Reliable, distributable binary.

- [ ] Unit tests for serdes, dependency parser, mod_list, settings, blueprint, changelog
- [ ] Go driver for the language-neutral e2e suite (`e2e/cases/`, created in
      the dry-* simplification Stage 0) — running it against both binaries on
      the branch is the Ruby-vs-Go parity check
- [ ] Reuse the Ruby fixtures (`spec/fixtures`: `test-save.zip`, mod-list, changelog samples)
      as golden files for unit tests
- [ ] Integration tests for CLI commands using `httptest` for portal API
- [ ] `staticcheck` / `golangci-lint` in CI
- [ ] `.goreleaser.yaml`
  - Targets: `linux/amd64`, `linux/arm64`, `darwin/amd64`, `darwin/arm64`, `windows/amd64`
  - GitHub Releases with checksums
- [ ] Swap `main` to `go-rewrite`; remove Ruby sources and Ruby CI
  (history and the `ruby` branch retain them); update README and docs; tag `v1.0.0`

---

## Key Technical Challenges

### PropertyTree

Factorio's property tree is a recursive tagged union. In Go, represent it as:

```go
type PropertyTreeKind uint8

const (
    KindNone PropertyTreeKind = iota
    KindBool
    KindNumber
    KindString
    KindList
    KindDict
    KindSignedInt
    KindUnsignedInt
)

type PropertyTree struct {
    Kind  PropertyTreeKind
    Value any // bool | float64 | string | []PropertyTree | map[string]PropertyTree | int64 | uint64
}
```

This is still runtime-checked — type assertions move inside kind-checked accessor
methods rather than disappearing. The gain over bare `any` is a single, tested
place where the checks live, not compile-time safety.

### Space-Optimized Integers

Factorio uses variable-length encoding for `optim_u16` and `optim_u32`.
These are 1-byte values under 0xFF, or a 0xFF sentinel followed by the full value.
Straightforward to implement but must be tested with fixture files extracted from real saves.

### Dependency Parser

The dependency string grammar is context-free and small (4 prefixes, 5 operators),
but MOD names may contain spaces, so the scanner must resolve name/operator
boundaries. A hand-rolled recursive descent parser (~50 lines) handles this
without a parser-library dependency.

### WSL Detection

`runtime.GOOS` returns `"linux"` on WSL. Detect WSL by reading `/proc/version`
and checking for the string `microsoft` (case-insensitive), matching the Ruby implementation.

---

## Out of Scope (Initial Release)

- **Redis and S3 cache backends** — intentional regression from the Ruby version.
  Rationale: they exist for shared-cache scenarios that conflict with the
  single-binary goal (extra dependencies: go-redis, aws-sdk-go-v2); the filesystem
  backend covers CLI usage. Revisit on demand.
- **Library API** — CLI-only binary; no importable package surface
  (`internal/` enforces this).
