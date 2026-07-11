# Factorix - Code Instructions for AI Coding Agents

## What is Factorix?

A Go CLI tool for Factorio MOD management, settings synchronization, and MOD Portal integration.

## Documentation Map

| Purpose | Document |
|---------|----------|
| Project overview & usage | [README.md](README.md) |
| Development guide | [DEVELOPMENT.md](DEVELOPMENT.md) |
| Architecture & technology stack | [doc/architecture.md](doc/architecture.md) |
| Feature overview | [doc/overview.md](doc/overview.md) |
| All documentation | [doc/README.md](doc/README.md) |

Package-level documentation lives in Go doc comments on each `internal/*`
package (run `go doc ./internal/...` or browse the source) rather than in
separate component docs.

## Core Principles

### Language Policy

- **Code & documentation**: English
- **Commit messages**: English with `:emoji:` notation (e.g., `:sparkles:`, `:bug:`)
- **Chat**: Use the user's language

### Key Naming Convention

- **MOD** is uppercase in exported identifiers and user-facing messages (not `Mod` or `mod`)
  - Type names: `MODList`, `MODVersion`
  - Messages: `"MOD not found"`
  - Unexported identifiers follow Go convention: `modList`, `mod`

### Skills

- Explore available skills and use them proactively when applicable

## Development Commands

```bash
mise run default   # Run all checks (test + e2e + vet + lint + fmt-check)
mise run test      # Run Go tests
mise run e2e       # Run the e2e cases against a freshly built binary
mise run lint      # Run golangci-lint (includes staticcheck)
mise run fmt       # Format Go files
```
