# Development Guide

This guide covers the development setup, architecture, and contribution guidelines for Factorix.

## Getting Started

### Prerequisites

- Ruby >= 3.2

### Initial Setup

Clone the repository and run the setup script:

```bash
git clone https://github.com/sakuro/factorix.git
cd factorix
bin/setup
```

The setup script installs dependencies via `bundle install`.

### Interactive Console

Launch an interactive console with Factorix preloaded:

```bash
bin/console
```

This opens an IRB session where you can experiment with the Factorix API.

## Technology Stack

### Ruby Version

- **Required**: Ruby >= 3.2
- **CI tested**: Ruby 3.2, 3.3, 3.4

### Core Dependencies

#### Dry-rb Ecosystem
- `dry-auto_inject` (~> 1.0) - Dependency injection
- `dry-cli` (~> 1.0) - Command-line interface framework
- `dry-configurable` (~> 1.0) - Configuration management
- `dry-container` (~> 0.11) - Service container
- `dry-events` (~> 1.1) - Event system
- `dry-logger` (~> 1.2) - Logging

#### Utilities
- `zeitwerk` (~> 2.7) - Code autoloading
- `retriable` (~> 3.1) - Retry logic for network operations
- `tty-progressbar` (~> 0.18) - Progress indication
- `rubyzip` (~> 2.3) - ZIP file handling
- `parslet` (~> 2.0) - Parser construction
- `concurrent-ruby` (~> 1.0) - Concurrency primitives

### Development Tools

#### Testing
- **RSpec** - Test framework
- **WebMock** - HTTP request mocking
- **SimpleCov** - Code coverage reporting

#### Code Quality
- **RuboCop** - Ruby linter and formatter
  - `rubocop-performance` - Performance cops
  - `rubocop-rake` - Rake-specific cops
  - `rubocop-rspec` - RSpec-specific cops
  - `rubocop-thread_safety` - Thread safety cops
  - `docquet` - Shared RuboCop configuration

#### Type Checking
- **Steep** - Static type checker for Ruby
- **RBS** - Ruby type signature files (in `sig/` directory)

#### Documentation
- **YARD** - Documentation generator

## Project Structure

### Directory Layout

```
factorix/
├── exe/                       # Executables
│   └── factorix               # CLI entry point
├── lib/factorix/              # Main source code
│   ├── api/                   # API clients
│   ├── cache/                 # Caching system
│   ├── cli/                   # CLI framework
│   │   └── commands/          # CLI command implementations
│   ├── dependency/            # Dependency management
│   ├── http/                  # HTTP operations
│   ├── progress/              # Progress indication
│   ├── runtime/               # Platform-specific code
│   ├── ser_des/               # Serialization/Deserialization
│   └── types/                 # Data models
├── spec/                      # RSpec tests
├── sig/                       # RBS type signatures
├── bin/                       # Development executables
│   ├── setup                  # Setup script
│   └── console                # Interactive console
└── .github/workflows/         # CI/CD
```

### Key Modules and Classes

- **`Factorix::Application`** - DI container (Dry::Container) and configuration (Dry::Configurable)
- **`Factorix::Portal`** - High-level API facade
- **`Factorix::CLI`** - Command registry (Dry::CLI)
- **`Factorix::MOD`** - Mod entity representation
- **`Factorix::Dependency::Resolver`** - Dependency resolution
- **`Factorix::SaveFile`** - Save file parser

### Design Patterns

- **Dependency Injection**: Dry::Container + Dry::AutoInject
- **Service Container**: Centralized dependency management
- **Decorator**: HTTP caching and retry decorators
- **Adapter**: Progress presenter adapter for tty-progressbar
- **Flyweight**: Memory-efficient object sharing
- **Strategy**: Runtime detection for platform-specific behavior

## Coding Conventions

### Ruby Style Guidelines

#### RuboCop Configuration
- **Strategy**: EnabledByDefault: true (very strict)
- **Shared config**: Inherits from `docquet` gem
- **Target Ruby**: 3.2+

#### Method Definition Style
- **Endless Methods**: Use endless method syntax for single-line method definitions
  ```ruby
  def simple_method = result
  ```
- **Access Scope Modifiers**: Apply access scope modifiers (like `private`) to individual methods
  ```ruby
  private def helper_method = ...
  ```

#### Data Class Definition Style
Define Data classes without blocks, then reopen the class for method definitions:
```ruby
# First define the Data class
SaveFile = Data.define(:version, :mods, :startup_settings)

# Then reopen the class for documentation and methods
# Documentation goes on the reopened class
class SaveFile
  # Class methods and instance methods here
end
```

#### Naming Conventions
- Use Zeitwerk naming conventions
- Special inflections: `api` => `API`, `http` => `HTTP`, `mod_*` => `MOD*`

### Testing Style
- **RSpec** with `expect` syntax (no should syntax)
- **NEVER use `described_class`**: Always use explicit class names in RSpec tests
- Mock HTTP requests with WebMock
- Measure coverage with SimpleCov

### Documentation Style
- **YARD format** for all public APIs
- Include `@example`, `@param`, `@return`, `@raise` tags where appropriate

## Development Workflow

### Running Tests

Run all tests:
```bash
bundle exec rake spec
```

Run specific test:
```bash
bundle exec rspec spec/path/to/spec_file.rb
bundle exec rspec spec/path/to/spec_file.rb:42  # Run specific line
```

### Code Linting

Run RuboCop:
```bash
bundle exec rubocop
```

Auto-fix safe offenses:
```bash
bundle exec rubocop -a
```

### Type Checking

Run Steep type checker:
```bash
bundle exec steep check
```

### Running All Quality Checks

Run tests, linting, and type checking:
```bash
bundle exec rake
```

This is the default task that runs: `spec`, `rubocop`, and `steep`.

### Task Completion Checklist

Before committing:
- [ ] All tests pass (`bundle exec rake spec`)
- [ ] No RuboCop violations (`bundle exec rubocop`)
- [ ] Type checking passes (`bundle exec steep check`)
- [ ] New code has tests
- [ ] Public APIs are documented with YARD
- [ ] Type signatures updated if applicable

## Troubleshooting

### Log Files

Factorix and Factorio generate log files that can help diagnose issues.

**View all paths including log files:**
```bash
bundle exec exe/factorix path
```

**Log file locations:**
- **Factorix log**: `factorix-log-path` - Factorix application logs
- **Factorio current log**: `current-log-path` - Current Factorio session log
- **Factorio previous log**: `previous-log-path` - Previous Factorio session log

**Accessing log paths programmatically:**
```ruby
runtime = Factorix::Application[:runtime]
runtime.factorix_log_path    # Factorix log file
runtime.current_log_path     # Factorio current log
runtime.previous_log_path    # Factorio previous log
```

## Contributing

### Bug Reports

When reporting bugs, please include:
- Ruby version
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Relevant error messages and stack traces

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b my-new-feature`)
3. Make your changes following the coding conventions
4. Add tests for your changes
5. Ensure all tests pass and code quality checks succeed
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
- Passing CI checks (tests, linting, type checking)
- Code review approval
- No merge conflicts with main branch

## Release Process

### Version Numbering

Factorix follows [Semantic Versioning](https://semver.org/):
- MAJOR version for incompatible API changes
- MINOR version for new functionality in a backwards compatible manner
- PATCH version for backwards compatible bug fixes

### Publishing a Release

Releases are automated via GitHub Actions workflows. See `.github/workflows/README.md` for complete documentation.

#### Quick Release Steps

1. **Prepare Changes**
   - Update `CHANGELOG.md` with changes in the `[Unreleased]` section
   - Commit and push to `main` branch

2. **Trigger Release**
   ```bash
   gh workflow run release-preparation.yml -f version=1.0.0
   ```
   Or use GitHub Actions UI: Actions → Release Preparation → Run workflow

3. **Review Release PR**
   - Automated PR will be created with version updates
   - CI and validation workflows run automatically
   - Review changes in `version.rb` and `CHANGELOG.md`

4. **Merge and Publish**
   ```bash
   gh pr merge release-v1.0.0 --merge
   ```
   - Merging automatically triggers gem publishing to RubyGems
   - GitHub release is created with changelog and gem file

5. **Verify**
   - Check RubyGems: `https://rubygems.org/gems/factorix`
   - Check GitHub releases: `https://github.com/sakuro/factorix/releases`

#### First Release Setup

For the first release, configure RubyGems Trusted Publishing:
1. Go to https://rubygems.org/oidc/pending_trusted_publishers
2. Create pending trusted publisher:
   - Gem name: `factorix`
   - Repository owner: `sakuro`
   - Repository name: `factorix`
   - Workflow filename: `release-publish.yml`
   - Environment name: `release`

See `.github/workflows/README.md` for detailed setup and troubleshooting.

## Additional Resources

- [Factorio Wiki](https://wiki.factorio.com/)
- [Factorio Lua API](https://lua-api.factorio.com/latest/)
- [Dry-rb Documentation](https://dry-rb.org/)
- [RuboCop Documentation](https://docs.rubocop.org/)
- [Steep Documentation](https://github.com/soutaro/steep)
