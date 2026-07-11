# Development Guide

This guide covers the development setup, architecture, and contribution guidelines for Factorix.

## Getting Started

### Prerequisites

- [mise](https://mise.jdx.dev/) — manages the Go toolchain and dev tools (golangci-lint, goreleaser) per `mise.toml`

### Initial Setup

Clone the repository and install the toolchain:

```bash
git clone https://github.com/sakuro/factorix.git
cd factorix
mise install
```

### Building

```bash
mise run build   # builds ./factorix
```

## Project Structure

See [`doc/architecture.md`](doc/architecture.md) for the package layout and technology stack.

## Language Policy

### Communication and Documentation

- **Code comments**: English
- **Technical documentation**: English (doc/ directory, README.md)
- **Commit messages**: English with GitHub emoji notation (`:emoji:` format)
- **PR/Issue titles and descriptions**: English

## Coding Conventions

### Naming Conventions

- `MOD` is uppercase in exported identifiers and user-facing messages (not `Mod` or `mod`)
  - Type names: `MODList`, `MODVersion`, `MODSettings`
  - Messages: `"MOD directory does not exist"`
  - Unexported identifiers follow Go convention: `modList`, `modDir`, `mods`
- Other abbreviations: `API`, `CLI`, `HTTP`, `MacOS`, `WSL`

### Linting

`golangci-lint` (bundling `staticcheck`, `errcheck`, `unused`, `unconvert`, `unparam`) runs via `mise run lint`; configuration and its documented exceptions live in `.golangci.yml`.

## Development Workflow

### Running Tests

```bash
mise run test              # go test ./...
mise run e2e                # e2e cases against a freshly built binary
go test ./internal/mod/...  # a single package
```

### Running All Quality Checks

```bash
mise run default   # test + e2e + vet + lint + fmt-check
```

### Task Completion Checklist

Before committing:
- [ ] `mise run default` passes
- [ ] New code has tests
- [ ] Exported identifiers have doc comments

## Troubleshooting

### Log Files

Factorix and Factorio generate log files that can help diagnose issues.

**View all paths including log files:**
```bash
factorix path
```

**Log file locations:**
- **Factorix log**: `factorix_log_path` - Factorix application logs
- **Factorio current log**: `current_log_path` - Current Factorio session log
- **Factorio previous log**: `previous_log_path` - Previous Factorio session log

## Contributing

### Bug Reports

When reporting bugs, please include:
- Factorix version (`factorix version`)
- Operating system and architecture
- Steps to reproduce
- Expected vs actual behavior
- Relevant error messages

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b my-new-feature`)
3. Make your changes following the coding conventions
4. Add tests for your changes
5. Ensure `mise run default` passes
6. Update documentation if needed
7. Commit your changes with clear commit messages
8. Push to your fork
9. Open a Pull Request

### Commit Messages

Use GitHub emoji notation (`:emoji:` format) for commit message prefixes:
- `:sparkles:` - New feature
- `:bug:` - Bug fix
- `:memo:` - Documentation changes
- `:art:` - Code style/formatting changes
- `:recycle:` - Code refactoring
- `:white_check_mark:` - Test additions or changes
- `:wrench:` - Configuration changes
- `:bookmark:` - Version bump/release preparation
- `:arrow_up:` - Upgrade dependencies
- `:arrow_down:` - Downgrade dependencies

### Code Review Process

All pull requests require:
- Passing CI checks (build, vet, lint, test, e2e)
- Code review approval
- No merge conflicts with main branch

## Release Process

Factorix follows [Semantic Versioning](https://semver.org/). Releases are cut by pushing a `vX.Y.Z` tag, which triggers `.github/workflows/go-release.yml` to build and publish binaries for all supported platforms via goreleaser (see `.goreleaser.yaml`). Validate a release build locally without publishing:

```bash
mise run release-snapshot
```

## Additional Resources

- [Factorio Wiki](https://wiki.factorio.com/)
- [Factorio Lua API](https://lua-api.factorio.com/latest/)
- [golangci-lint Documentation](https://golangci-lint.run/)
- [goreleaser Documentation](https://goreleaser.com/)
