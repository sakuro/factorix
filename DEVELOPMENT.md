# Development Guidelines

This document provides comprehensive development guidelines and standards for
contributors to the Factorix project, ensuring consistency and quality across
the codebase.

AI code assistance tools should also read this document to understand
the codebase and make consistent suggestions and modifications.

## Project Overview

Factorix is a Ruby library and CLI that provides a module management system.

## Code Architecture

Factorix consists of the following main components:

- **Mod**: Base class representing modules
- **ModList**: Manages collections of modules
- **ModState**: Tracks module states (enabled/disabled)
- **Runtime**: Provides runtime environments for different OS environments
  (Linux, macOS, Windows, WSL)
- **CLI**: Command-line interface and command implementations

## File Structure Conventions

```
lib/factorix/                 # Main code
├── cli/                      # CLI command implementations
│   └── commands/             # Individual commands
│       └── mod/              # Module-related commands
├── runtime/                  # OS-specific implementations
spec/                         # Test code (RSpec)
├── fixtures/                 # Test data
└── support/                  # Test helpers
```

## Coding Conventions

### Language Specifications

- Target Ruby 3.4 and above
- Actively utilize latest Ruby language features (pattern matching, keyword
  arguments, etc.)
- Type information defined in RBS files under the `sig/` directory

### Style Rules

As a fundamental principle, code should be formatted using RuboCop

- Indentation: 2 spaces
- Maximum line length: 120 characters
- Method names: `snake_case`
- Class names: `PascalCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Strings: Generally use double quotes. Use `%[...]` notation when escaping would be cumbersome.
- Hash notation: Use Ruby 2.0+ syntax (`{ key: value }`) whenever possible

### Design Principles

- **Single Responsibility Principle**: Each class has a clearly defined single
  responsibility
- **Dependency Injection**: External dependencies injected via constructor
- **Explicit Interfaces**: Public APIs clearly documented
- **Immutability Preferred**: Use immutable objects when possible
- **Exception Handling**: Define exception classes at appropriate granularity and use
  intentionally

## Documentation Conventions

- Use [YARD](https://yardoc.org/) format documentation for public APIs
- Describe the purpose and responsibility of each class
- Document inputs, outputs, and side effects of each method
- Add comments explaining implementation intent for complex logic
- When starting documentation with a verb, use the infinitive form
- Place an empty line between the documentation text and the tag block (starting with @)

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

## Testing Strategy

- Unit tests: Functionality of individual classes and methods
- Integration tests: Interactions between components
- Mocks/stubs: Isolate external dependencies
- Fixtures: Located in the `spec/fixtures/` directory
- Coverage goal: 90%+ code coverage

## Error Handling

- Use custom exception classes instead of standard Ruby exception classes
- All exceptions defined within the `Factorix::Errors` module
- Error messages are clear and contain information helpful for problem
  resolution
- Distinguish between recoverable and non-recoverable errors

## Performance Considerations

- Efficiently handle large numbers of modules
- Minimize memory usage
- Report progress for long-running operations
- Consider buffering and asynchronous processing for file I/O and network
  operations

## Versioning

- Follow [Semantic Versioning](https://semver.org/)
- Major version: Breaking changes
- Minor version: Backward-compatible feature additions
- Patch version: Backward-compatible bug fixes

## Commit Message Conventions

Commit messages follow a structured format to maintain clarity and consistency.

### Emoji Prefix

Each commit message starts with a single emoji that represents the type of change.
Use GitHub emoji notation (e.g., `:sparkles:`).

| Emoji Code      | Emoji | Description                                           |
|-----------------|-------|-------------------------------------------------------|
| `:new:`         | 🆕    | New feature – Adding a new feature or capability      |
| `:beetle:`      | 🪲    | Bug fix – Fixing an issue or bug                      |
| `:memo:`        | 📝    | Documentation – Writing or updating documentation     |
| `:policeman:`   | 👮    | RuboCop – Addressing RuboCop suggestions              |
| `:lipstick:`    | 💄    | Style – Code style changes (formatting, linting)      |
| `:hammer:`      | 🔨    | Refactor – Code changes that neither fix a bug nor add a feature |
| `:zap:`         | ⚡    | Performance – Improving performance                   |
| `:test_tube:`   | 🧪    | Tests – Adding or updating tests                      |
| `:recycle:`     | ♻️    | Remove – Removing code or files                       |
| `:bookmark:`    | 🔖    | Release – Tagging for release                         |
| `:wrench:`      | 🔧    | Config – Configuration or build system changes        |
| `:gem:`         | 💎    | Dependency – Adding or updating dependencies (Ruby)   |
| `:package:`     | 📦    | Dependency – Adding or updating dependencies (non-Ruby) |
| `:rewind:`      | ⏪    | Revert – Reverting changes                            |
| `:rocket:`      | 🚀    | Deploy – Deploying stuff                              |
| `:inbox_tray:`  | 📥    | Merge – Merging branches                              |
| `:truck:`       | 🚚    | Move – Moving or renaming files                       |
| `:bulb:`        | 💡    | Idea – Idea or proposal                               |
| `:construction:`| 🚧    | WIP – Work in progress                                |
| `:computer:`    | 💻    | Terminal operation – Result of invoking some commands |
| `:tada:`        | 🎉    | Initial – Initial commit                              |

### Message Structure

- Start with the emoji prefix
- Follow with a concise description in present tense
- Begin the description with a verb (e.g., "Add", "Fix", "Update")
- Keep the message focused on what the commit does

### Co-authorship

For collaborative work, include co-authors using the following format:
```
Co-authored-by: Name <email@example.com>
```

### Examples

```
:new: Add mod list command with format options
:beetle: Fix missing require in mod list command
:recycle: Remove unnecessary comment about backward compatibility
:inbox_tray: Merge pull request #17 from sakuro/rewrite-readme
```

This convention makes the commit history more readable and helps quickly
identify the purpose of each change.

## Additional Guidelines for AI Code Generation

- Generate code that matches existing patterns and styles
- Include appropriate YARD documentation for new classes and methods
- Add explanatory comments for complex logic
- Prioritize designs that facilitate testing
- Minimize and explicitly manage dependencies
- Follow existing error handling patterns
- Consider performance and memory usage
- When creating RBS type definitions:
  - Use per-method `private` keyword instead of section-based approach
  - Create directory structures that mirror the implementation code
  - Validate syntax using the `rbs validate` command after creation
  - Ensure consistency between YARD documentation and type definitions
  - Take special care when defining types for classes using Data.define
  - Consider type definitions for external libraries when necessary

---

These guidelines will be updated as the project evolves. AI tools are expected to reference this
document to make code suggestions consistent with the project's design philosophy.
