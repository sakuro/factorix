# Code Quality Management

## Basic Principles

1. **Gradual Response**: Classify violations by priority and address them gradually
2. **Appropriate Exclusion**: Properly exclude violations that require complex refactoring
3. **Consistency Maintenance**: Prioritize unified coding standards across the team

## RuboCop Management

### Violation Check and Classification

```bash
# Check all violations
bundle exec rubocop

# Check violations in specific file
bundle exec rubocop path/to/file.rb
```

#### Violation Priority Classification

**High Priority (Immediate Response)**
- **Style/CommentedKeyword**: Comments on class definition lines
- **Layout/LineLength**: Line length limit exceeded
- **Layout/ExtraSpacing**: Unnecessary whitespace
- **Layout/EmptyLinesAroundModuleBody**: Empty lines around modules

**Medium Priority (Planned Response)**
- **Style/ConstantVisibility**: Constant visibility specification
- **Naming/VariableNumber**: Variable naming conventions

**Low Priority (Consider Exclusion)**
- **Metrics/MethodLength**: Method length
- **Metrics/AbcSize**: Method complexity
- **Metrics/ClassLength**: Class length

### Auto-corrections

```bash
# Safe auto-correction (recommended)
bundle exec rubocop -a

# All auto-corrections (execute with caution)
bundle exec rubocop -A
```

**Important Notes**:
- The `-A` flag may include destructive changes, so create a git stash or commit beforehand
- Always run tests after auto-correction to verify functionality

### Manual Corrections

#### Style/CommentedKeyword Response Example

```ruby
# Before correction
class HTTPClientError < HTTPError; end      # 4xx series

# After correction
class HTTPClientError < HTTPError; end
```

#### Layout/LineLength Response Example

```ruby
# Before correction
raise ModPortalValidationError, "Invalid version: #{version}. Valid values are: #{VALID_VERSIONS.join(", ")}"

# After correction
raise ModPortalValidationError,
  "Invalid version: #{version}. Valid values are: #{VALID_VERSIONS.join(", ")}"
```

### Exclude Complex Violations

```bash
# Regenerate TODO file to exclude violations
bundle exec rake rubocop:regenerate_todo
```

**Examples of violations to exclude**:
- `Metrics/MethodLength` requiring large-scale method splitting
- `Metrics/AbcSize` requiring architectural changes
- `Style/Documentation` in legacy code

### Commit Strategy for RuboCop Fixes

#### Separate commits by violation type

```bash
# Style fix commit
git add -p  # Selectively stage target files
git commit -m ":police_officer: Fix Style/CommentedKeyword violations"

# Exclusion settings commit
git add .rubocop_todo.yml
git commit -m ":police_officer: Regenerate RuboCop TODO to exclude complex violations"
```

## Commit Message Patterns for Code Quality

### Auto-correction
```
:police_officer: Auto-fix layout and style violations

- Fix Layout/EmptyLinesAroundModuleBody
- Fix Layout/LineLength by splitting long lines
- Fix Layout/TrailingWhitespace
```

### Manual correction
```
:police_officer: Fix Style/CommentedKeyword violations

Remove inline comments from class definitions to comply with rubocop rules.
Class purposes are documented in design documentation.
```

### Exclusion settings
```
:police_officer: Regenerate RuboCop TODO to exclude complex violations

Regenerate .rubocop_todo.yml to exclude remaining Metrics violations
that require significant refactoring.
```

## Common Issues and Solutions

### 1. Auto-correction doesn't work as expected

**Cause**: Dependent violations exist
**Solution**: Fix gradually and run rubocop at each stage

### 2. Tests fail

**Cause**: Unintended changes due to auto-correction
**Solution**: Check changes in detail with `git diff` and manually fix if necessary

### 3. Exclusion settings not reflected

**Cause**: Misconfiguration in `.rubocop_todo.yml`
**Solution**: Regenerate with `bundle exec rake rubocop:regenerate_todo`

## Best Practices

1. **Small commits**: Fine-grained commits by violation type
2. **Test execution**: Always run test suite after corrections
3. **Review requests**: Request code review after large-scale auto-corrections
4. **Document updates**: Update related documentation when style guide changes

## Exclusion Decision Criteria

### Violations to exclude
- Require large-scale refactoring (effort > 1 day)
- Involve architectural changes
- High risk of impact on existing functionality

### Violations to address
- Can be resolved with simple fixes (effort < 1 hour)
- Directly affect readability
- Important items related to team conventions

## Development Workflow Integration

As part of the standard development workflow, code quality verification is essential:

1. **Before Committing**: Always run `bundle exec rubocop` to check for violations
2. **During PR Review**: Ensure all RuboCop issues are resolved or properly documented  
3. **Continuous Integration**: RuboCop checks should be part of the CI pipeline
4. **Code Quality**: RuboCop helps maintain consistent code style and catches potential issues

This ensures consistent code quality and maintainability across the project.

## Related Commands

```bash
# Run specific cop only
bundle exec rubocop --only Style/CommentedKeyword

# Run excluding specific cop
bundle exec rubocop --except Metrics/MethodLength

# Run with specific config file
bundle exec rubocop --config .rubocop_todo.yml

# Testing commands
bundle exec rspec

# Type checking (if applicable)
bundle exec steep check

# Documentation generation
bundle exec yard
```