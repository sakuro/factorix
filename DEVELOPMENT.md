# Development Guidelines

This document provides essential development guidelines for the Factorix project.
AI assistants may find additional guidance in MEMORY_BANK.md if interested.

## Project Overview

Factorix is a Ruby library and CLI for Factorio mod management.

## Code Architecture

- **Mod**: Base class for modules
- **ModList**: Manages module collections
- **ModState**: Tracks module states
- **Runtime**: OS-specific environments
- **CLI**: Command-line interface

## Coding Conventions

- Ruby 3.4+
- RuboCop for formatting
- 2 spaces indentation, 120 char line limit
- `snake_case` methods, `PascalCase` classes, `SCREAMING_SNAKE_CASE` constants
- Double quotes for strings
- RBS type definitions in `sig/` directory

## Design Principles

- Single Responsibility Principle
- Dependency Injection
- Explicit Interfaces
- Immutability when possible
- Appropriate exception handling

## Documentation

- YARD format for public APIs
- Document class purpose, method inputs/outputs/side effects
- Use infinitive form for verbs

## Testing

- Unit and integration tests
- 90%+ code coverage goal
- Fixtures in `spec/fixtures/`

## Error Handling

- Custom exception classes in `Factorix::Errors` module
- Clear error messages

## Versioning

- Follow Semantic Versioning (semver.org)

## Commit Messages

Format: Emoji prefix + concise present tense description

Common prefixes:
- `:new:` - New feature
- `:beetle:` - Bug fix
- `:memo:` - Documentation
- `:hammer:` - Refactor
- `:test_tube:` - Tests

## RBS Type Definitions

- Use per-method `private` keyword instead of section-based approach
- Create directory structures that mirror the implementation code
- Validate syntax using the `rbs validate` command after creation
- Ensure consistency between YARD documentation and type definitions
- Take special care when defining types for classes using Data.define
- Consider type definitions for external libraries when necessary

---

AI assistants should consult MEMORY_BANK.md for more comprehensive guidelines if interested.
