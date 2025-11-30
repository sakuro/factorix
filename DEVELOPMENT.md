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

See [`doc/technology-stack.md`](doc/technology-stack.md) for details.

- **Required Ruby version**: >= 3.2
- **CI tested**: Ruby 3.2, 3.3, 3.4

## Project Structure

See [`doc/architecture.md`](doc/architecture.md) for detailed class hierarchy and design patterns.

## Language Policy

### Communication and Documentation

- **Code comments**: English (YARD format for Ruby)
- **Technical documentation**: English (doc/ directory, README.md)
- **Commit messages**: English with GitHub emoji notation (`:emoji:` format)
- **PR/Issue titles and descriptions**: English

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

- `MOD` is always uppercase (not `Mod` or `mod`)
- Other abbreviations: `API`, `CLI`, `HTTP`, `MacOS`, `WSL`

See [`doc/architecture.md`](doc/architecture.md) for Zeitwerk configuration and file-to-class mapping details.

### Testing Style
- **RSpec** with `expect` syntax (no should syntax)
- **NEVER use `described_class`**: Always use explicit class names in RSpec tests
- Mock HTTP requests with WebMock
- Measure coverage with SimpleCov

### Documentation Style
- **YARD format** for all public APIs
- Include `@example`, `@param`, `@return`, `@raise` tags where appropriate

### CLI Output Guidelines

Commands should use two distinct output methods based on the nature of the output:

#### `say(message, prefix: "")` - Human-readable messages

**Purpose:** Interactive feedback, status updates, progress indicators

**Behavior:**
- Respects `--quiet` flag (suppressed in quiet mode)
- Supports prefixes (`:error`, `:warn`) with emoji indicators
- Intended for human consumption

**Use cases:**
- Status updates: `say "✓ Saved mod-list.json"`
- Progress indicators: `say "Validating MOD dependencies..."`
- Success messages: `say "Metadata updated successfully!"`
- Warnings: `say "Warning message", prefix: :warn`
- Errors: `say "Error message", prefix: :error`

#### `puts(data)` - Data output

**Purpose:** Primary command output for piping, scripting, or direct display

**Behavior:**
- Always outputs regardless of `--quiet` flag
- No prefix or formatting added
- The "main result" of the command

**Formats:**
- JSON (using `JSON.pretty_generate`) for machine consumption
- Tables (text-based) for human-readable listings

**Use cases:**
- Data export/listing operations (MOD list, search results, image list)
- Structured information queries (path, version)
- Any output that represents the command's primary result

#### Selection Guidelines

1. **Data query commands** (output as primary purpose) → Use `puts` for data
   ```ruby
   def call(path_types: [], **)
     result = build_path_data(path_types)
     puts JSON.pretty_generate(result)  # Always output, even with --quiet
   end
   ```

2. **Action commands** (perform operations) → Use `say` for feedback
   ```ruby
   def call(mod_names:, **)
     say "Planning to disable #{mod_names.size} MOD(s):"
     perform_action
     say "Saved mod-list.json", prefix: :success
   end
   ```

3. **Mixed commands** (optional data output) → Use both appropriately
   ```ruby
   def call(settings_file: nil, output: nil, **)
     say "Loading settings..."  # Progress feedback
     data = load_settings(settings_file)
     if output
       write_file(output, data)
       say "Exported to #{output}", prefix: :success  # Success feedback
     else
       puts JSON.pretty_generate(data)  # Data output to stdout
     end
   end
   ```

#### Key Principle

**If the output is the primary value** (data that users/scripts need to capture), use `puts`. **If the output is feedback about what happened**, use `say`.

### Exception Handling in CLI Commands

All CLI commands inherit from `CLI::Commands::Base`, which automatically prepends the `CommandWrapper` module. This module is prepended to intercept all command execution and provides centralized exception handling.

#### CommandWrapper Exception Capture Mechanism

When a command is executed, [`CommandWrapper#call`](lib/factorix/cli/commands/command_wrapper.rb) wraps the actual command implementation with a two-tier exception handling strategy:

1. Perform common setup (options handling, configuration loading, log level)
2. Call the actual command implementation via `super`
3. Catch and handle exceptions based on their type

#### Exception Handling Tiers and Exit Codes

The top-level [`exe/factorix`](exe/factorix) script maps exceptions to exit codes:

| Exit Code | Exception Type | Examples | Logging | User Message |
|-----------|----------------|----------|---------|--------------|
| 0 | (none) | Normal completion | - | - |
| 1 | `Factorix::Error` | `ValidationError`, `GameRunningError`, `HTTPClientError` | Warning (message), Debug (full) | "Error: {message}" |
| 2 | Other exceptions | `StandardError`, `RuntimeError`, programming errors | Error (full details) | "Unexpected error: {message}" |

#### Implications for Command Implementation

Commands should:
- **Raise appropriate exceptions** instead of calling `exit` directly
- **Let exceptions propagate** to CommandWrapper (don't rescue unless necessary)
- **Use domain-specific exceptions** (subclasses of `Factorix::Error`) for expected error conditions
- **Trust the wrapper** to handle logging and user-facing error messages

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
- **Factorix log**: `factorix_log_path` - Factorix application logs
- **Factorio current log**: `current_log_path` - Current Factorio session log
- **Factorio previous log**: `previous_log_path` - Previous Factorio session log

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

Releases are automated via GitHub Actions workflows. See [`.github/workflows/README.md`](.github/workflows/README.md) for complete documentation.

#### Quick Release Steps

1. **Prepare Changes**
   - Update [`CHANGELOG.md`](CHANGELOG.md) with changes in the `[Unreleased]` section
   - Commit and push to `main` branch

2. **Trigger Release**
   ```bash
   gh workflow run release-preparation.yml -f version=1.0.0
   ```
   Or use GitHub Actions UI: Actions → Release Preparation → Run workflow

3. **Review Release PR**
   - Automated PR will be created with version updates
   - CI and validation workflows run automatically
   - Review changes in [`version.rb`](lib/factorix/version.rb) and [`CHANGELOG.md`](CHANGELOG.md)

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

See [`.github/workflows/README.md`](.github/workflows/README.md) for detailed setup and troubleshooting.

## Additional Resources

- [Factorio Wiki](https://wiki.factorio.com/)
- [Factorio Lua API](https://lua-api.factorio.com/latest/)
- [Dry-rb Documentation](https://dry-rb.org/)
- [RuboCop Documentation](https://docs.rubocop.org/)
- [Steep Documentation](https://github.com/soutaro/steep)
