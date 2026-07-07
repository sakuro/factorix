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

---

## Stage 1 — dry-events → Listener Callbacks

Affected: `installed_mod`, `transfer/downloader`, `transfer/uploader`,
`http/cache_decorator`, `api/mod_portal_api`, `api/mod_management_api`, and the
three `progress/*_handler` classes.

- [ ] Define listener interfaces mirroring the Go design (`ProgressListener` with
      `on_started(total:)` / `on_progress(current:)` / `on_completed(total:)`),
      one per domain (download, upload, scan)
- [ ] Remove `Dry::Events::Publisher[...]` mixins and `register_event`/`publish`;
      publishers accept an optional listener (`nil` means no reporting — same
      convention as the Go plan)
- [ ] Convert `progress/*_handler` classes from event-payload receivers to direct
      listener implementations
- [ ] Replace the `MODManagementAPI` → `MODPortalAPI` cache-invalidation
      subscription with an explicit callback on the management client
- [ ] Remove dry-events from the gemspec

---

## Stage 2 — dry-configurable → Plain Config + TOML

- [ ] Plain nested value objects (`Data`) with current defaults; keep the
      `Factorix.config` accessor to limit churn (injection happens in Stage 4)
- [ ] Config file becomes `config.toml` (same XDG directory; currently
      `config.rb` evaluated with `instance_eval`), parsed with perfect_toml
- [ ] Key structure unchanged: `log_level`, `runtime.*`, `rcon.*`, `http.*`,
      `cache.{download,api,info_json}.*`
- [ ] Migration path: if `config.toml` is absent but `config.rb` exists,
      evaluate the legacy DSL once and emit the equivalent TOML with
      `PerfectTOML.generate`, then abort asking the user to review and save it
- [ ] Update `components/configuration.md` and README config examples
- [ ] Remove dry-configurable from the gemspec

Moving to TOML now (rather than at the Go port) means users migrate their config
file once; the Go version then reads the same file.

---

## Stage 3 — dry-logger → stdlib Logger

- [ ] Thin wrapper around stdlib `Logger` preserving the structured-payload call
      style (`logger.debug("message", key: value)`) so the ~35 files of call
      sites stay unchanged; payload rendered as `key=value` pairs
- [ ] Same log file path and template (`[time] SEVERITY: message payload`);
      level from `config.log_level`
- [ ] Remove dry-logger from the gemspec

---

## Stage 4 — DI Container → Constructor Injection

The largest stage: `include Import[...]` appears in 35 files.

- [ ] `Factorix::Application` composition root — a plain class with memoized
      readers mirroring the container registrations (`runtime`, `logger`, caches,
      decorated HTTP clients, API clients, `portal`, …); `downloader` stays
      non-memoized (per-download event listeners)
- [ ] Decorator chains assembled in the composition root, unchanged:
      API `Client → Cache → Retry`; download/upload `Client → Retry`
- [ ] Replace `include Import[...]` with keyword-argument constructors;
      specs inject doubles directly instead of stubbing the container
- [ ] Replace the dry-inflector `classify` call in cache construction with an
      explicit backend map (`file_system:`, `redis:`, `s3:`)
- [ ] Remove `container.rb` and the `Import` constant; rewrite
      `components/container.md` as composition-root documentation
- [ ] Remove dry-auto_inject, dry-core, and dry-inflector from the gemspec

dry-cli instantiates command classes with no arguments, so command constructors
use keyword defaults resolving from the application instance
(`def initialize(runtime: Factorix.app.runtime)`). This service-locator seam is
confined to the CLI boundary; in Go, cobra wiring in `main.go` takes its place.

---

## Ordering Rationale

1. Stage 1 is independent and smallest, and validates the Go listener design early.
2. Stage 2 precedes Stage 4 because the container reads `Factorix.config`.
3. Stage 3 precedes Stage 4 so the logger moves into the composition root already
   in its final stdlib form.

## Verification

- Full test suite and steep green at every stage
- Manual smoke test per stage: `mod list`, `mod download` (progress bar),
  `mod settings dump`
- CHANGELOG entry per stage; the config file migration (Stage 2) is called out
  in the release notes
