# Commit and PR Workflow Guide

## Basic Principles

1. **Logical Separation**: Separate functional changes from style fixes
2. **Clear History**: Each commit should have a single purpose
3. **Reviewability**: PRs should have appropriate size and description

## Branch Strategy

### Branch Creation

```bash
# Create feature branch
git checkout -b feature/description-of-change

# Create refactoring branch
git checkout -b refactor/description-of-refactoring
```

#### Branch Naming Conventions

- **feature/**: New feature addition
- **refactor/**: Refactoring
- **fix/**: Bug fixes
- **docs/**: Documentation updates
- **style/**: Code style fixes

## Commit Strategy

### 1. Gradual Commits

#### Logically divide large changes

```bash
# Example: Exception hierarchy redesign

# 1. Define new exception classes
git add lib/factorix/errors.rb sig/factorix/errors.rbs
git commit -m ":hammer: Redesign exception hierarchy with 3-layer architecture"

# 2. Update existing code
git add lib/factorix/runtime.rb lib/factorix/http_client.rb
git commit -m ":hammer: Update existing code to use new exception hierarchy"

# 3. Update tests
git add spec/
git commit -m ":white_check_mark: Update tests for new exception hierarchy"

# 4. Style fixes
git add lib/factorix/errors.rb
git commit -m ":police_officer: Fix Style/CommentedKeyword violations"
```

### 2. Commit Modification and Integration

#### Interactive Rebase

```bash
# Edit recent 3 commits
git rebase -i HEAD~3

# When integrating commits
pick abc1234 :hammer: Redesign exception hierarchy
squash def5678 :fire: Remove backward compatibility alias
pick ghi9012 :police_officer: Fix style violations
```

#### Commit Splitting

```bash
# Split latest commit
git reset --soft HEAD^
git add -p  # Selectively stage changes
git commit -m ":police_officer: Fix Style/CommentedKeyword violations"
git add .
git commit -m ":fire: Remove backward compatibility alias"
```

### 3. Commit Message Guidelines

#### Basic Format

```
:emoji: Brief description in imperative mood

Optional detailed explanation of the changes and their motivation.
Use bullet points for multiple changes:
- Change 1 with explanation
- Change 2 with explanation

:robot: Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

#### Emoji Guidelines

**Notation Format**: Always use GitHub emoji notation (`:emoji:`) in commit messages, not raw Unicode emojis (:no_entry_sign:). This ensures consistency and compatibility across different Git tools and platforms.

**GitHub Emoji Set**: Only use emojis that are part of GitHub's official emoji set when writing commit messages. Non-GitHub emojis should be avoided or replaced with appropriate GitHub emoji alternatives.

##### Available Emojis

- `:new:` - New feature - Adding a new feature or capability
- `:beetle:` - Bug fix - Fixing an issue or bug
- `:memo:` - Documentation - Writing or updating documentation
- `:lipstick:` - Style - Code style changes (formatting, linting)
- `:hammer:` - Refactor - Code changes that neither fix a bug nor add a feature
- `:zap:` - Performance - Improving performance
- `:test_tube:` - Tests - Adding or updating tests
- `:recycle:` - Remove - Removing code or files
- `:bookmark:` - Release - Tagging for release
- `:wrench:` - Config - Configuration or build system changes
- `:gem:` - Dependency - Adding or updating dependencies (Ruby)
- `:package:` - Dependency - Adding or updating dependencies (non Ruby)
- `:rewind:` - Revert - Reverting changes
- `:rocket:` - Deploy - Deploying stuff
- `:inbox_tray:` - Merge - Merging branches
- `:truck:` - Move - Moving or renaming files
- `:bulb:` - Idea - Idea or proposal
- `:construction:` - WIP - Work in progress
- `:computer:` - Terminal operation - Result of invoking some commands
- `:tada:` - Initial - Initial commit

## PR Creation and Management

### 1. Pre-PR Creation Checklist

```bash
# Run tests
bundle exec rspec

# Run RuboCop
bundle exec rubocop

# Run type checking (if applicable)
bundle exec steep check

# Verify YARD documentation generation
bundle exec yard
```

### 2. PR Creation

```bash
# Push branch
git push -u origin feature/branch-name

# Create PR
gh pr create --title ":hammer: Brief description of changes" --body "$(cat <<'EOF'
## Summary

Brief overview of what this PR accomplishes.

## Key Changes

### Main Changes
- Change 1 with detailed explanation
- Change 2 with detailed explanation

### Technical Details
- Technical consideration 1
- Technical consideration 2

## Test Plan

- [x] All existing tests pass
- [x] New tests added for new functionality
- [x] Manual testing completed
- [x] Edge cases considered
- [x] RuboCop violations resolved or properly excluded

## Breaking Changes

None / List any breaking changes

## Architecture Benefits

1. **Benefit 1**: Explanation
2. **Benefit 2**: Explanation

:robot: Generated with [Claude Code](https://claude.ai/code)
EOF
)"
```

### 3. PR Description Components

#### Required Sections
- **Summary**: Overview of changes
- **Key Changes**: Major changes
- **Test Plan**: Test plan and checklist

#### Recommended Sections
- **Technical Details**: Technical details
- **Breaking Changes**: Breaking changes
- **Architecture Benefits**: Architectural benefits

### 4. Review Response

#### Review Comment Response Example

```markdown
@reviewer Thanks for the review! Regarding the [specific concern]:

While I understand the concern about [issue], I've chosen to keep the current implementation for the following reasons:

1. **Technical Reason**: Detailed explanation of technical choice
2. **Context Consideration**: Explanation of specific context (e.g., CLI vs library)
3. **Trade-off Analysis**: Explanation of trade-offs considered

The current implementation prioritizes [priority] over [alternative], which I believe is appropriate for this use case.
```

## Advanced Git Operations

### 1. Commit History Organization

#### Multiple Commit Integration

```bash
# Integrate feature commits and style fixes
git reset --soft HEAD~2
git commit -m ":hammer: Feature implementation with style fixes

- Implement main feature functionality
- Fix related RuboCop violations
- Update tests and documentation"
```

#### Commit Order Changes

```bash
git rebase -i HEAD~4
# Change order in editor
pick ghi9012 :hammer: Main feature
pick def5678 :lipstick: Style fixes
pick abc1234 :test_tube: Tests
pick jkl3456 :memo: Documentation
```

### 2. Selective Change Staging

```bash
# Stage only specific changes within file
git add -p file.rb

# Stage specific lines only (interactive mode)
git add -i
```

### 3. Emergency Fix Response

```bash
# Temporarily save work in progress
git stash push -m "Work in progress"

# Fix in hotfix branch
git checkout -b hotfix/urgent-fix
# Fix work
git commit -m ":beetle: Fix urgent issue"

# Return to original branch and continue work
git checkout feature/original-work
git stash pop
```

## CI/CD Integration

### 1. Pre-push Hook Response

```bash
# Prepare for automatic checks before push
git add .
git commit -m ":lipstick: Pre-push fixes"
git push
# RuboCop/RSpec executed by hooks
```

### 2. Failure Response

```bash
# Fix when CI fails
git add .
git commit --amend --no-edit
git push --force-with-lease
```

## Best Practices

### 1. Commit Granularity

- **1 commit = 1 logical change**
- **Maintain compilable/testable state**
- **Reviewable size (guideline: < 500 lines changed)**
- **Verify RuboCop compliance before committing**

### 2. Branch Management

- **Short-lived branches**: Merge within 1-2 weeks
- **Regular rebase**: Sync with main branch
- **Branch deletion after merge**: `git branch -d feature-branch`

### 3. PR Management

- **Appropriate size**: 1 PR = 1 feature/fix
- **Sufficient explanation**: Clearly state why the change is needed
- **Quick review**: Target initial review within 24 hours

## Development Workflow Integration

As part of the standard development workflow, RuboCop verification is essential:

1. **Before Committing**: Always run `bundle exec rubocop` to check for violations
2. **During PR Review**: Ensure all RuboCop issues are resolved or properly documented  
3. **Continuous Integration**: RuboCop checks should be part of the CI pipeline
4. **Code Quality**: RuboCop helps maintain consistent code style and catches potential issues

This ensures consistent code quality and maintainability across the project. For detailed RuboCop response procedures, refer to the RuboCop Response Guide.

## Troubleshooting

### Common Issues and Solutions

#### 1. Conflict Resolution

```bash
# Conflicts during rebase
git rebase main
# After resolving conflicts
git add .
git rebase --continue
```

#### 2. Incorrect Commit Fixes

```bash
# Fix latest commit
git commit --amend

# Fix past commits
git rebase -i HEAD~n
# Change target commit to 'edit'
```

#### 3. Pushed Commit Fixes

```bash
# Safe force push
git push --force-with-lease
```

## Related Command Reference

```bash
# History verification
git log --oneline -10
git log --graph --oneline --all

# Change verification
git diff HEAD~1
git diff --staged

# Branch operations
git branch -a  # Show all branches
git branch -d branch-name  # Delete branch

# Remote sync
git fetch origin
git pull --rebase origin main
```