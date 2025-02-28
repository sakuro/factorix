# Factorix Memory Bank

This document serves as a structured knowledge base for the Factorix project, designed to be easily referenced by both human developers and AI assistants. It contains key information extracted from development guidelines and project documentation.

## Project Overview

- **Name**: Factorix
- **Type**: Ruby library and CLI tool
- **Purpose**: Factorio game mod management and launching
- **Target Ruby Version**: 3.4+

## Code Architecture

- **Mod**: Base class representing modules
- **ModList**: Manages collections of modules
- **ModState**: Tracks module states (enabled/disabled)
- **Runtime**: Provides runtime environments for different OS environments (Linux, macOS, Windows, WSL)
- **CLI**: Command-line interface and command implementations

## File Structure

```
lib/factorix/                 # Main code
├── cli/                      # CLI command implementations
│   └── commands/             # Individual commands
│       └── mod/              # Module-related commands
├── runtime/                  # OS-specific implementations
sig/                          # Type definitions (RBS)
spec/                         # Test code (RSpec)
├── fixtures/                 # Test data
└── support/                  # Test helpers
```

## Coding Conventions

### Language

- Ruby 3.4+
- Modern Ruby features: pattern matching, keyword arguments, etc.
- RBS type definitions in `sig/` directory

### Style

- Formatting: RuboCop
- Indentation: 2 spaces
- Line length: max 120 characters
- Naming:
  - Methods: `snake_case`
  - Classes: `PascalCase`
  - Constants: `SCREAMING_SNAKE_CASE`
- Strings: Double quotes preferred, `%[...]` for complex escaping
- Hash syntax: `{ key: value }` (Ruby 2.0+)

## Design Principles

- **Single Responsibility**: Each class has one clearly defined responsibility
- **Dependency Injection**: External dependencies injected via constructor
- **Explicit Interfaces**: Public APIs clearly documented
- **Immutability**: Prefer immutable objects when possible
- **Exception Handling**: Use appropriate granularity for exception classes

## Documentation

- Format: [YARD](https://yardoc.org/)
- Document:
  - Class purpose and responsibility
  - Method inputs, outputs, and side effects
  - Implementation intent for complex logic
- Style:
  - Use infinitive form for verbs
  - Empty line between text and tag block

Example:
```ruby
# Create MOD
#
# @param name [String] Module name
# @param version [String] Version in semantic versioning format
# @param dependencies [Array<String>] Array of dependent module names
# @return [Mod] Created Mod object
# @raise [InvalidModError] If module definition is invalid
def create_mod(name, version, dependencies = [])
  # Implementation...
end
```

## Testing

- **Unit Tests**: Individual classes and methods
- **Integration Tests**: Component interactions
- **Mocks/Stubs**: For external dependencies
- **Fixtures**: In `spec/fixtures/` directory
- **Coverage Goal**: 90%+

## Error Handling

- Use custom exception classes (not standard Ruby exceptions)
- Define all exceptions in `Factorix::Errors` module
- Error messages should be clear and helpful
- Distinguish between recoverable and non-recoverable errors

## Performance

- Efficiently handle large numbers of modules
- Minimize memory usage
- Report progress for long-running operations
- Consider buffering and async processing for I/O operations

## Versioning

- Follow [Semantic Versioning](https://semver.org/)
- **Major**: Breaking changes
- **Minor**: Backward-compatible features
- **Patch**: Backward-compatible fixes

## Commit Messages

- Format: Emoji prefix + concise present tense description
- Start description with a verb (Add, Fix, Update, etc.)
- Common emoji prefixes:
  - `:new:` (🆕) - New feature
  - `:beetle:` (🪲) - Bug fix
  - `:memo:` (📝) - Documentation
  - `:hammer:` (🔨) - Refactor
  - `:test_tube:` (🧪) - Tests

## RBS Type Definitions

- Use per-method `private` keyword instead of section-based approach
- Create directory structures mirroring implementation code
- Validate syntax with `rbs validate`
- Ensure consistency between YARD docs and type definitions
- Take special care with Data.define classes
- Consider external library type definitions when needed

## Development Workflow

- Ensure RuboCop and RSpec pass successfully before pushing changes
- Run tests locally to verify functionality
- Follow the branch-based development model
- Create pull requests for code reviews
- Use `:inbox_tray:` (📥) emoji prefix for merge commits
- Format merge commit messages as `:inbox_tray: Merge pull request #N: [PR title]`

## AI Guidelines

When generating or modifying code for this project:

- Match existing patterns and styles
- Include YARD documentation for new code
- Add explanatory comments for complex logic
- Design for testability
- Minimize dependencies
- Follow established error handling patterns
- Consider performance implications

---

Last updated: 2025-02-28
