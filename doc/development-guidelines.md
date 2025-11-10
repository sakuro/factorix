# Development Guidelines

This document defines development standards and conventions for the Factorix reimplementation project.

## Language Policy

### Communication Language

- **User communication**: Use Japanese
- **Internal project discussion**: Use Japanese
- **Clear and concise expressions**: Use technical terms appropriately

### Code and Documentation Language

#### Source Code
- **Code comments**: Write in English
- **Complex logic explanations**: Write detailed explanations in English
- **Follow programming language conventions**: Use YARD format for Ruby

#### Documentation
- **Technical documentation**: Write in English (`doc/` directory)
- **README**: Write in English
- **Architecture documentation**: Write in English

#### Version Control
- **Commit messages**: Write in English
- **Conventional Commits format**: Use GitHub emoji codes
- **PR titles and descriptions**: Write in English
- **Issue titles and descriptions**: Write in English

## Project Structure

### Directory Structure

```
factorix/
├── doc/                      # Project documentation (English)
│   ├── architecture.md       # Architecture design
│   ├── implementation-plan.md # Implementation plan
│   ├── overview.md           # Project overview
│   ├── technology-stack.md   # Technology stack
│   └── components/           # Component detailed design
├── lib/
│   └── factorix/
│       ├── runtime/          # Phase 1: Foundation layer
│       ├── api/              # Phase 3: External communication (low-level)
│       ├── types/            # Phase 4: Data models
│       ├── cli/              # Phase 6: CLI layer
│       └── ...
├── sig/                      # RBS type definitions
│   └── factorix/             # Mirrors lib/ structure
├── spec/                     # Test code
└── ...
```

### Implementation Order by Phase

Follow the order specified in `doc/implementation-plan.md`:

1. **Phase 1**: Runtime, Error, SerDes (Foundation layer)
2. **Phase 2**: Credentials, Application (Authentication & configuration)
3. **Phase 3**: Transfer, API (External communication, low-level)
4. **Phase 4**: Types, MODDependencies, Portal (Data models)
5. **Phase 5**: Cache, MODList, MODSettings (Storage)
6. **Phase 6**: CLI Commands (CLI layer)

## Coding Conventions

### Ruby Style Guide

- **RuboCop**: Use automatic style checking
- **Auto-fix**: Use `bundle exec rubocop -A` to auto-fix as much as possible
- **Pre-commit check**: Always run RuboCop before committing

### Naming Conventions

#### MOD Notation
- **Always uppercase**: `MOD` (not `Mod` or `mod`)
- **Zeitwerk configuration**: Specify all class names containing MOD individually in inflector
- **Important**: Compound words containing MOD require individual configuration
- **File names**: `mod_list.rb` → `Factorix::MODList`
- **Examples**:
  - `mod_list.rb` → `Factorix::MODList`
  - `mod_dependency.rb` → `Factorix::MODDependency`
  - `mod_info.rb` → `Factorix::MODInfo`
  - `mod_version.rb` → `Factorix::MODVersion`
  - `mod_download_api.rb` → `Factorix::API::MODDownloadAPI`
  - `mod_portal_api.rb` → `Factorix::API::MODPortalAPI`

#### Other Abbreviations
- `API` → Uppercase (`api.rb` → `Factorix::API`)
- `CLI` → Uppercase (`cli.rb` → `Factorix::CLI`)
- `HTTP` → Uppercase (`http.rb` → `Factorix::HTTP`)
- `MacOS` → CamelCase (`mac_os.rb` → `Runtime::MacOS`)
- `WSL` → Uppercase (`wsl.rb` → `Runtime::WSL`)

### Zeitwerk Configuration

Current configuration in `lib/factorix.rb`:

```ruby
loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/factorix/version.rb")
loader.ignore("#{__dir__}/factorix/errors.rb")
loader.inflector.inflect(
  "api" => "API",
  "api_credential" => "APICredential",
  "http" => "HTTP",
  "mac_os" => "MacOS",
  "mod_download_api" => "MODDownloadAPI",
  "mod_info" => "MODInfo",
  "mod_portal_api" => "MODPortalAPI",
  "mod_version" => "MODVersion",
  "wsl" => "WSL"
)
loader.setup
```

### Dependency Injection (DI)

- **Use dry-auto_inject**
- **Application container**: `Factorix::Application` is the center
- **Import module**: `Import = Dry::AutoInject(Factorix::Application)`

```ruby
class SomeClass
  include Import["cache", "logger"]

  def some_method
    logger.info "Using injected dependencies"
    cache.get("key")
  end
end
```

### Data Models

- **Use Data.define** (Ruby 3.2+)
- **Immutable**: All value objects are immutable
- **Place under Types**: `Factorix::Types::*`

```ruby
module Factorix
  module Types
    class MODInfo < Data.define(
      :name,
      :title,
      :owner,
      :summary,
      :category,
      :downloads_count,
      :releases
    )
    end
  end
end
```

**To add custom methods**: Do not use `do...end` block. Reopen the class instead:

```ruby
module Factorix
  module Types
    class MODInfo
      def latest_version
        releases.max_by(&:released_at)&.version
      end
    end
  end
end
```

## Type Definitions (RBS)

### RBS Policy

- **sig/ directory**: Mirrors lib/ structure
- **Type definitions for each class/module**: Always define types for public APIs
- **Incremental adoption**: Add type definitions per Phase
- **Type checking with Steep**: Use `steep check` for static type checking (included in default rake task)

### Directory Structure

```
sig/
└── factorix/
    ├── runtime.rbs           # Type definitions for lib/factorix/runtime.rb
    ├── runtime/
    │   ├── base.rbs          # Type definitions for lib/factorix/runtime/base.rb
    │   ├── linux.rbs
    │   ├── mac_os.rbs
    │   ├── windows.rbs
    │   └── wsl.rbs
    ├── api/
    │   ├── public_api.rbs
    │   ├── download_api.rbs
    │   └── portal_api.rbs
    └── ...
```

### Writing RBS Files

**Basic format**:
```rbs
module Factorix
  # Runtime environment abstraction
  class Runtime
    # Return the MODs directory path
    #
    # @return [Pathname] the MODs directory of Factorio
    def mods_dir: () -> Pathname

    # Return XDG cache home directory
    #
    # @return [Pathname] the XDG cache home directory
    def xdg_cache_home_dir: () -> Pathname

    # Launch the game with options
    #
    # @param options [Array<String>] command-line options
    # @param async [Boolean] whether to launch asynchronously
    # @return [void]
    def launch: (*String options, async: bool) -> void
  end
end
```

**For Data.define**:
```rbs
module Factorix
  module Types
    # MOD information from API
    class MODInfo < Data
      def name: () -> String
      def title: () -> String
      def owner: () -> String
      def summary: () -> String
      def category: () -> String
      def downloads_count: () -> Integer
      def releases: () -> Array[Release]

      def initialize: (
        name: String,
        title: String,
        owner: String,
        summary: String,
        category: String,
        downloads_count: Integer,
        releases: Array[Release]
      ) -> void
    end
  end
end
```

### Using rbs Commands

#### Validating Type Definitions

```bash
# Validate all type definitions (syntax and consistency)
bundle exec rbs validate

# Check syntax of specific file
bundle exec rbs parse sig/factorix/runtime.rbs

# Display type definition environment
bundle exec rbs environment
```

#### Debugging

```bash
# Validate with detailed logging
bundle exec rbs validate --log-level=debug

# Display type definitions for specific class
bundle exec rbs prototype rb lib/factorix/runtime/base.rb
```

### Type Definition Maintenance

1. **Add type definitions with implementation**: When adding new classes/methods, add RBS at the same time
2. **Validate at Phase completion**: Verify type definition consistency with `bundle exec rbs validate`
3. **Pre-commit check**: Validate RBS along with RSpec and RuboCop

### Pre-commit Checklist (with RBS)

```bash
# 1. Run tests
bundle exec rspec

# 2. Style check
bundle exec rubocop

# 3. Validate type definitions
bundle exec rbs validate

# 4. Commit if all succeed
git add lib/factorix/runtime/base.rb
git add sig/factorix/runtime/base.rbs
git add spec/factorix/runtime/base_spec.rb
git commit -m "..."
```

## Testing Policy

### Test Frameworks

- **RSpec**: Test framework
- **WebMock**: Stub HTTP requests
- **SimpleCov**: Coverage measurement (under consideration)

### Test Structure

```
spec/
├── factorix/
│   ├── runtime/
│   │   ├── base_spec.rb
│   │   ├── linux_spec.rb
│   │   ├── mac_os_spec.rb
│   │   ├── windows_spec.rb
│   │   └── wsl_spec.rb
│   ├── api/
│   │   ├── public_api_spec.rb
│   │   ├── download_api_spec.rb
│   │   └── portal_api_spec.rb
│   └── ...
└── spec_helper.rb
```

### Test Principles

1. **Test each component independently**: Focus on unit tests
2. **Stub HTTP requests with WebMock**: For API/Transfer layer testing
3. **Write tests per Phase**: Write tests alongside implementation
4. **Reference old implementation**: Test code available in `factorix.old/spec/`
5. **Aim for high coverage**: Always test critical parts

### WebMock Usage Example

```ruby
RSpec.describe Factorix::API::PublicAPI do
  describe "#get_mod_info" do
    before do
      stub_request(:get, "https://mods.factorio.com/api/mods/some-mod")
        .to_return(
          status: 200,
          body: File.read("spec/fixtures/api/mod_info.json"),
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns mod information as Hash" do
      api = described_class.new
      result = api.get_mod_info("some-mod")

      expect(result).to be_a(Hash)
      expect(result["name"]).to eq("some-mod")
    end
  end
end
```

## File Format Standards

### Text Files

- **UTF-8 encoding**: All text files
- **Unix-style line endings**: Use LF (Line Feed)
- **Newline at end of file**: All text files end with newline (`\n`, not `\n\n`)

### Indentation and Spacing

- **Ruby**: 2-space indentation
- **Remove trailing whitespace**: Remove from all lines
- **Consistency**: Unified style across the entire project

### Configuration Files

- **YAML/JSON/TOML**: Choose appropriate format
- **Comments**: Include comments as needed
- **Validation**: Check syntax before committing

## Git Operations

### Branch Strategy

- **main branch**: Stable, releasable state
- **feature branches**: New feature development (optional)
- **Implementation per Phase**: Proceed incrementally with small commits

### Commit Message Format

**Required format**:
```
:emoji: Imperative subject line (English)

Brief explanation of change (optional, English)
- Key changes
- Important notes
```

**Note**: AI may add the following attribution:
```
:robot: Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Rules**:
- **Write in English**: All commit messages in English
- **GitHub emoji codes**: `:bug:`, `:sparkles:`, etc. (no Unicode emojis)
- **Imperative mood**: "Fix" not "Fixed"
- **Be concise**: Short subject line, essential points only in body
- **Use heredoc**: Use `<<'EOF'` for complex messages
- **Important**: Do not mention abandoned/reverted implementations before commit (don't write about what's not in history)

**Common emoji codes**:
- `:sparkles:` - New features
- `:bug:` - Bug fixes
- `:memo:` - Documentation
- `:recycle:` - Refactoring
- `:white_check_mark:` - Add/update tests
- `:package:` - Update dependencies
- `:wrench:` - Configuration changes
- `:art:` - Code structure/format improvements
- `:zap:` - Performance improvements
- `:fire:` - Remove code/files

### Pre-commit Checklist

1. **Run tests**: `bundle exec rspec`
2. **Run RuboCop**: `bundle exec rubocop`
3. **Validate RBS**: `bundle exec rbs validate`
4. **Check changes**: `git status` and `git diff`
5. **Add files explicitly**: `git add path/to/file.rb` (never `git add .`)
6. **Verify staging**: `git diff --cached`

### File Addition Principles

**Prohibited**:
```bash
git add .      # ❌ Adds all files
git add -A     # ❌ Adds all tracked and untracked files
git add *      # ❌ Adds files with glob pattern
```

**Recommended**:
```bash
# Check changes
git status
git diff

# Add files explicitly
git add lib/factorix/runtime/base.rb
git add sig/factorix/runtime/base.rbs
git add spec/factorix/runtime/base_spec.rb

# Verify staging
git diff --cached

# Commit (using heredoc)
git commit -m "$(cat <<'EOF'
:sparkles: Add Runtime::Base abstract class

Define platform abstraction interface with XDG directory support.
EOF
)"
```

**Importance of heredoc**:
- **Always use `<<'EOF'`**: Enclosed in single quotes (not `<<EOF`)
- **Prevent variable expansion**: Shell variables and special characters are handled safely
- **Multi-line messages**: Required for commit messages with body

### Commit Examples

#### Example 1: Adding New Feature

```bash
git add lib/factorix/runtime/base.rb
git add sig/factorix/runtime/base.rbs
git add spec/factorix/runtime/base_spec.rb

git commit -m "$(cat <<'EOF'
:sparkles: Add Runtime::Base abstract class

Define platform abstraction interface including:
- XDG directory methods (xdg_cache_home_dir, etc.)
- Platform-specific path retrieval
- Abstract methods for subclasses
EOF
)"
```

#### Example 2: Bug Fix

```bash
git add lib/factorix/mod_dependency_parser.rb
git add spec/factorix/mod_dependency_parser_spec.rb

git commit -m "$(cat <<'EOF'
:bug: Fix version constraint parsing for optional dependencies

Handle '?' prefix correctly when parsing version constraints.
EOF
)"
```

#### Example 3: Documentation Update

```bash
git add README.md

git commit -m "$(cat <<'EOF'
:memo: Update installation instructions

Add Ruby 3.2+ requirement and RBS setup steps.
EOF
)"
```

#### Example 4: Simple Commit (No Body Needed)

```bash
git add lib/factorix/version.rb

git commit -m "$(cat <<'EOF'
:package: Bump version to 0.2.0
EOF
)"
```

**Note**: When subject line is sufficiently clear, detailed explanation can be omitted.

## Pull Requests (PR)

### Pre-PR Checklist

- [ ] All tests pass (`bundle exec rspec`)
- [ ] No RuboCop violations (`bundle exec rubocop`)
- [ ] RBS type definitions correct (`bundle exec rbs validate`)
- [ ] Commit messages follow conventions
- [ ] Related documentation updated

### PR Title and Description

- **Title**: In English, same format as commit messages
- **Description**: In English, describe background and purpose of changes
- **Related issues**: Link like `Fixes #123` if applicable

### PR Example

```markdown
## Summary

Implement Runtime abstraction layer for cross-platform support.

## Changes

- Add `Runtime::Base` abstract class
- Implement platform-specific subclasses (Linux, macOS, Windows, WSL)
- Add XDG Base Directory specification support
- Include comprehensive RBS type definitions

## Testing

- Unit tests for all Runtime classes
- Platform detection logic covered
- XDG directory resolution tested

## Related Documentation

- Updates to `doc/components/runtime.md`
- Phase 1 checklist items completed in `doc/implementation-plan.md`
```

## Development Workflow

### Starting a Phase

1. **Review documentation**: Check Phase details in `doc/implementation-plan.md`
2. **Reference old implementation**: Check `factorix.old/` if existing code available
3. **Review design**: Check component design in `doc/components/`

### During Implementation

1. **Test-driven**: Write tests first (when possible)
2. **Implementation**: Write code
3. **Type definitions**: Add RBS files
4. **Small commits**: Commit incrementally per feature
5. **Follow RuboCop**: Always follow style guide
6. **Check dependencies**: Maintain Phase order

### Completing a Phase

1. **Check checklist**: Verify items in `doc/implementation-plan.md`
2. **Verify test coverage**: Confirm critical features are tested
3. **Validate RBS**: Check type definitions with `bundle exec rbs validate`
4. **Update documentation**: Update design documents as needed
5. **Move to next Phase**: Verify dependencies before proceeding

## Reference Implementation

### Using Old Implementation

- **Directory**: `factorix.old/`
- **Purpose**: Understand design philosophy, test cases, edge cases
- **Note**: Do not copy directly, reimplement following new design principles

### Files to Reference

#### Implementation Code
- `factorix.old/lib/factorix/runtime/*.rb` - Runtime implementation
- `factorix.old/lib/factorix/mod_dependency*.rb` - Dependency analysis
- `factorix.old/lib/factorix/ser_des/*.rb` - SerDes implementation

#### Type Definitions
- `factorix.old/sig/factorix/runtime.rbs` - Runtime type definitions
- `factorix.old/sig/factorix/*.rbs` - Other type definitions

#### Test Code
- `factorix.old/spec/**/*_spec.rb` - Test cases

## Code Review Criteria

### Checklist

- [ ] No RuboCop violations
- [ ] Tests added
- [ ] RBS type definitions added
- [ ] `bundle exec rbs validate` succeeds
- [ ] Commit messages follow conventions
- [ ] Naming conventions (MOD, etc.) followed
- [ ] Zeitwerk autoload works correctly
- [ ] Dependency injection used appropriately
- [ ] Documentation updated (if needed)

## Troubleshooting

### Zeitwerk Autoload Error

```
NameError: uninitialized constant Factorix::Mod
```

**Cause**: Missing inflector configuration

**Solution**: Add `loader.inflector.inflect("mod" => "MOD")`

### RuboCop Violations

**Auto-fix**:
```bash
bundle exec rubocop -A
```

**Manual review required**:
```bash
bundle exec rubocop --only Layout/LineLength
```

### RBS Validation Errors

**Syntax errors**:
```bash
bundle exec rbs parse sig/factorix/runtime.rbs
```

**Type inconsistencies**:
```bash
bundle exec rbs validate --log-level=debug
```

### Test Failures

**Detailed output**:
```bash
bundle exec rspec --format documentation
```

**Run specific file only**:
```bash
bundle exec rspec spec/factorix/runtime/base_spec.rb
```

## Related Documentation

- [Architecture](architecture.md) - System architecture
- [Implementation Plan](implementation-plan.md) - Implementation plan and checklist
- [Technology Stack](technology-stack.md) - Technology stack
- [Component Details](components/) - Component detailed design
