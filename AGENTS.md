# Factorix - Code Instructions for AI Coding Agents

## What is Factorix?

A Ruby gem providing a CLI for Factorio MOD management, settings synchronization, and MOD Portal integration.

## Documentation Map

| Purpose | Document |
|---------|----------|
| Project overview & usage | [README.md](README.md) |
| Development guide | [DEVELOPMENT.md](DEVELOPMENT.md) |
| Architecture & technology stack | [doc/architecture.md](doc/architecture.md) |
| Feature overview | [doc/overview.md](doc/overview.md) |
| All documentation | [doc/README.md](doc/README.md) |

### Component Documentation

Located in [doc/components/](doc/components/):

- [cli.md](doc/components/cli.md) - CLI commands
- [api-portal.md](doc/components/api-portal.md) - MOD Portal API integration
- [container.md](doc/components/container.md) - DI container
- [storage.md](doc/components/storage.md) - MOD storage management
- [runtime.md](doc/components/runtime.md) - Platform abstraction
- [credentials.md](doc/components/credentials.md) - Authentication

## Core Principles

### Language Policy

- **Code & documentation**: English
- **Commit messages**: English with `:emoji:` notation (e.g., `:sparkles:`, `:bug:`)
- **Chat**: Use the user's language

### Key Naming Convention

- **MOD** is uppercase in class names and user-facing messages (not `Mod` or `mod`)
  - Class names: `MODList`, `MODVersion`
  - Messages: `"MOD not found"`
  - Method/variable names follow Ruby convention: `mod_list`, `mod`

### Skills

- Explore available skills and use them proactively when applicable

## Development Commands

```bash
bundle exec rake          # Run all checks (spec + rubocop + steep)
bundle exec rspec         # Run tests
bundle exec rubocop -a    # Auto-fix style
bundle exec steep check   # Type checking
```
