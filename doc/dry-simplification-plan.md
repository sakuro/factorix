# dry-* Simplification Plan

## Overview

This document describes the plan to replace most dry-* infrastructure with plain
Ruby, as a precursor to the [Go migration](go-migration-roadmap.md). The Go port
eliminates the DI container, pub/sub events, and the configuration framework;
doing the same in Ruby first validates those design decisions in the existing
codebase and keeps the two implementations structurally close during the port.

This is separate from general dependency reduction — gems with direct Go
equivalents (rubyzip, retriable, tty-progressbar, concurrent-ruby) are not
touched here.

## Scope

| Gem | Replacement | Stage |
|-----|-------------|-------|
| dry-events | Listener callback interfaces | 1 |
| dry-configurable | Plain config value objects + TOML file | 2 |
| dry-logger | stdlib `Logger` behind a thin wrapper | 3 |
| dry-auto_inject, dry-core, dry-inflector | Constructor injection + composition root | 4 |

**Out of scope:** dry-cli (the Go version uses cobra; replacing it in Ruby does
not help the port) and zeitwerk. Net dependency change: −6 dry gems, +1 TOML
library ([perfect_toml](https://github.com/mame/perfect_toml) — pure Ruby,
TOML v1.0.0, no transitive dependencies, and its generator supports the config
migration below).

Each stage is one PR. `bundle exec rake` (spec + rubocop + steep) must pass,
including `sig/*.rbs` updates. No user-visible behavior changes except the
config file format (Stage 2).

Stage 0 adds a language-neutral e2e test suite before any refactoring: the
existing specs are coupled to Ruby internals (container stubs, mixins) and get
rewritten along with Stages 1–4, so they cannot serve as the safety net for
those refactors. The same suite later becomes the Ruby-vs-Go parity check in
the [Go migration roadmap](go-migration-roadmap.md) (Phase 11).

---

## Stage 0 — Language-Neutral CLI e2e Tests

Test cases are language-neutral *data*; only a thin driver is per-language
(RSpec now, `go test` after the port reads the same cases).

- [x] `e2e/cases/` at the repository root: one directory per case holding the
      command line, environment, fixture setup, and expected stdout / exit status
- [x] Thin RSpec driver that discovers and runs the cases against `exe/factorix`
- [x] Isolation via config runtime overrides (`user_dir` / `data_dir`) pointing
      into a per-case temporary directory
- [x] Output determinism: suppress the progress bar when stdout is not a TTY,
      honor `NO_COLOR`
- [x] Initial coverage — deterministic local commands only:
      `version`, `path`, `mod list`, `mod check`, `mod settings dump`,
      `blueprint encode` / `decode`, `mod changelog check` / `extract`
- [ ] Portal-dependent commands (`mod search`, `mod install`, …) are deferred:
      they need a mock portal server serving recorded API responses; add once
      the local-command suite is in place

---

## Stage 1 — dry-events → Listener Callbacks

Affected: `installed_mod`, `transfer/downloader`, `transfer/uploader`,
`http/cache_decorator`, `api/mod_portal_api`, `api/mod_management_api`, and the
three `progress/*_handler` classes.

- [x] Define listener interfaces mirroring the Go design (`ProgressListener` with
      `on_started(total:)` / `on_progress(current:)` / `on_completed`),
      one per domain (download, upload, scan)
- [x] Remove `Dry::Events::Publisher[...]` mixins and `register_event`/`publish`;
      publishers accept an optional listener (`nil` means no reporting — same
      convention as the Go plan)
- [x] Convert `progress/*_handler` classes from event-payload receivers to direct
      listener implementations
- [x] Replace the `MODManagementAPI` → `MODPortalAPI` cache-invalidation
      subscription with an explicit callback on the management client
- [x] Remove dry-events from the gemspec

---

## Stage 2 — dry-configurable → Plain Config + TOML

- [x] Plain nested value objects (`Data`) with current defaults; keep the
      `Factorix.config` accessor to limit churn (injection happens in Stage 4)
- [x] Config file becomes `config.toml` (same XDG directory; currently
      `config.rb` evaluated with `instance_eval`), parsed with perfect_toml
- [x] Key structure unchanged: `log_level`, `runtime.*`, `rcon.*`, `http.*`,
      `cache.{download,api,info_json}.*`
- [x] Migration path: if `config.toml` is absent but `config.rb` exists,
      evaluate the legacy DSL once and emit the equivalent TOML with
      `PerfectTOML.generate`, then abort asking the user to review and save it
- [x] Update `components/configuration.md` and README config examples
- [x] Remove dry-configurable from the gemspec

Moving to TOML now (rather than at the Go port) means users migrate their config
file once; the Go version then reads the same file.

---

## Stage 3 — dry-logger → stdlib Logger

- [x] Thin wrapper around stdlib `Logger` preserving the structured-payload call
      style (`logger.debug("message", key: value)`) so the ~35 files of call
      sites stay unchanged; payload rendered as `key=value` pairs
- [x] Same log file path and template (`[time] SEVERITY: message payload`);
      level from `config.log_level`
- [x] Remove dry-logger from the gemspec

---

## Stage 4 — DI Container → Constructor Injection

The largest stage: `include Import[...]` appears in 35 files.

- [x] `Factorix::Application` composition root — a plain class with memoized
      readers mirroring the container registrations (`runtime`, `logger`, caches,
      decorated HTTP clients, API clients, `portal`, …); `downloader` became
      memoizable in Stage 1 (listeners are per call), so everything is memoized
- [x] Decorator chains assembled in the composition root, unchanged:
      API `Client → Cache → Retry`; download/upload `Client → Retry`
- [x] Replace `include Import[...]` with keyword-argument constructors;
      specs inject doubles directly instead of stubbing the container
- [x] Replace the dry-inflector `classify` call in cache construction with an
      explicit backend map (`file_system:`, `redis:`, `s3:`)
- [x] Remove `container.rb` and the `Import` constant; rewrite
      `components/container.md` as composition-root documentation
      (`components/application.md`)
- [x] Remove dry-auto_inject, dry-core, and dry-inflector from the gemspec

dry-cli instantiates command classes with no arguments, so command constructors
use keyword defaults resolving from the application instance
(`def initialize(runtime: Factorix.app.runtime)`). This service-locator seam is
confined to the CLI boundary; in Go, cobra wiring in `main.go` takes its place.

---

## Ordering Rationale

1. Stage 0 comes first because every later stage relies on it as the
   refactoring safety net.
2. Stage 1 is independent and smallest, and validates the Go listener design early.
3. Stage 2 precedes Stage 4 because the container reads `Factorix.config`.
4. Stage 3 precedes Stage 4 so the logger moves into the composition root already
   in its final stdlib form.

## Verification

- Full test suite (unit + e2e) and steep green at every stage
- Manual smoke test per stage: `mod list`, `mod download` (progress bar),
  `mod settings dump`
- CHANGELOG entry per stage; the config file migration (Stage 2) is called out
  in the release notes
