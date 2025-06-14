# Git Workflow Guide

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

### Branch Naming Conventions

- **feature/**: New feature addition
- **refactor/**: Refactoring
- **fix/**: Bug fixes
- **docs/**: Documentation updates
- **style/**: Code style fixes

## Commit Strategy

### Gradual Commits

Logically divide large changes into smaller, focused commits:

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

### Commit Message Guidelines

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

**Scope**: These emoji guidelines apply to all git-managed content including commit messages, pull request descriptions, documentation, source code comments, and any other text files in the repository.

**Notation Format**: Always use GitHub emoji notation (`:emoji:`) instead of raw Unicode emojis. This ensures consistency and compatibility across different Git tools and platforms.

**GitHub Emoji Set**: Only use emojis that are part of GitHub's official emoji set.

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

## Advanced Git Operations

### Interactive Rebase

```bash
# Edit recent 3 commits
git rebase -i HEAD~3

# When integrating commits
pick abc1234 :hammer: Redesign exception hierarchy
squash def5678 :fire: Remove backward compatibility alias
pick ghi9012 :police_officer: Fix style violations
```

### Commit Splitting

```bash
# Split latest commit
git reset --soft HEAD^
git add -p  # Selectively stage changes
git commit -m ":police_officer: Fix Style/CommentedKeyword violations"
git add .
git commit -m ":fire: Remove backward compatibility alias"
```

### Selective Change Staging

```bash
# Stage only specific changes within file
git add -p file.rb

# Stage specific lines only (interactive mode)
git add -i
```

## Pull Request Management

### Pre-PR Creation Checklist

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

### PR Creation

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

### PR Description Components

#### Required Sections
- **Summary**: Overview of changes
- **Key Changes**: Major changes
- **Test Plan**: Test plan and checklist

#### Recommended Sections
- **Technical Details**: Technical details
- **Breaking Changes**: Breaking changes
- **Architecture Benefits**: Architectural benefits

## Best Practices

### Commit Granularity

- **1 commit = 1 logical change**
- **Maintain compilable/testable state**
- **Reviewable size (guideline: < 500 lines changed)**

### Branch Management

- **Short-lived branches**: Merge within 1-2 weeks
- **Regular rebase**: Sync with main branch
- **Branch deletion after merge**: `git branch -d feature-branch`

### PR Management

- **Appropriate size**: 1 PR = 1 feature/fix
- **Sufficient explanation**: Clearly state why the change is needed
- **Quick review**: Target initial review within 24 hours

## Troubleshooting

### Common Issues and Solutions

#### Conflict Resolution

```bash
# Conflicts during rebase
git rebase main
# After resolving conflicts
git add .
git rebase --continue
```

#### Incorrect Commit Fixes

```bash
# Fix latest commit
git commit --amend

# Fix past commits
git rebase -i HEAD~n
# Change target commit to 'edit'
```

#### Pushed Commit Fixes

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