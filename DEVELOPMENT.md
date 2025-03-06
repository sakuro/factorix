# Development Guidelines

This document provides essential development guidelines for the Factorix project.
AI assistants may find additional guidance in MEMORY_BANK.md if interested.

## Project Overview

Factorix is a Ruby library and CLI for Factorio mod management.

## Code Architecture

- **Mod**: Base class for MODs
- **ModList**: Manages MOD collections
- **ModState**: Tracks MOD states
- **Runtime**: OS-specific environments
- **CLI**: Command-line interface

## Coding Conventions

- Ruby 3.2+
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

- Use English for all documentation and comments
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

## Commit Messages and PR Descriptions

Format: Emoji prefix + concise present tense description

Start description with a verb (Add, Fix, Update, etc.)

Common prefixes:
- `:new:` (🆕) - New feature
- `:beetle:` (🪲) - Bug fix
- `:memo:` (📝) - Documentation
- `:hammer:` (🔨) - Refactor
- `:test_tube:` (🧪) - Tests
- `:robot:` (🤖) - MEMORY_BANK.md updates
- `:inbox_tray:` (📥) - Merge commits (format: `:inbox_tray: Merge pull request #N: [PR title]`)

### Command Line Usage for Messages

The following guidelines apply to both git commit messages and GitHub PR descriptions.

When creating messages with multiple lines or special characters:

- Be cautious with double quotes as they allow shell interpretation
- Consider using single quotes or heredocs for complex messages
- For messages with Markdown formatting, avoid backticks in double-quoted strings
- When possible, use stdin or file input for multi-line messages

#### Git Commit Examples

Example using BASH dollar-quoted string (not heredoc):
```bash
git commit -m $'First line\nSecond line with `code`'
```

Example using heredoc:
```bash
git commit <<EOF
:memo: Update documentation

- Add new section about X
- Improve examples for Y
- Fix typos in Z section
EOF
```

Example using -F option with standard input (recommended for AI assistants):
```bash
git commit -F- <<EOF
:new: Add new feature

- Implement X functionality
- Fix Y issue
EOF
```

# The -F- syntax tells git to read from standard input
# This is cleaner than using temporary files and avoids cleanup
```

#### GitHub PR Examples

Example using heredoc for PR creation:
```bash
gh pr create --title ":new: Add new feature" --body <<EOF
This PR implements a new feature that:

- Adds X functionality
- Improves Y performance
- Fixes Z issue

## Testing
- [x] Unit tests added
- [x] Integration tests passed
EOF
```

Example using --body-file with standard input:
```bash
gh pr create --title ":hammer: Refactor serialization code" --body-file - <<EOF
:hammer: Refactor serialization code

- Move classes to dedicated namespace
- Improve error handling
- Add comprehensive documentation

## Breaking Changes
None
EOF
```

# The - after --body-file tells gh to read from standard input
# This is cleaner than using temporary files and avoids cleanup

## RBS Type Definitions

- Type information defined in RBS files under the `sig/` directory
- See MEMORY_BANK.md for detailed guidelines on creating RBS type definitions

---

AI assistants should consult MEMORY_BANK.md for more comprehensive guidelines if interested.
