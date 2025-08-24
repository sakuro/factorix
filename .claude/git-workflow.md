# Git Workflow Guide

## Basic Principles

1. **Logical Separation**: Separate functional changes from style fixes
2. **Clear History**: Each commit should have a single purpose
3. **Reviewability**: PRs should have appropriate size and description

### Logical Commit Guidelines

**One Logical Change Per Commit**: Each commit should contain changes that logically belong together and serve a single purpose.

**Examples of What NOT to Mix**:
- **Logic changes + Style fixes**: Don't combine algorithm improvements with formatting changes
- **Feature + Bug fix**: Keep new features separate from unrelated bug fixes  
- **Multiple unrelated features**: Each feature should have its own commit(s)
- **Unrelated improvements**: Don't bundle unrelated code improvements in one commit

**Examples of What CAN Be Combined**:
- **Implementation + Related tests**: Tests that directly verify the implementation changes
- **Feature + Documentation**: Documentation that describes the new feature
- **Bug fix + Corresponding test**: Test that verifies the bug fix works

**Practical Example with Selective Staging**:

```bash
# You have mixed changes in a file: bug fix + style improvements
git add -p src/calculator.rb  # Select only bug fix changes
git commit -m ":beetle: Fix division by zero error"

git add -p src/calculator.rb  # Select remaining style changes
git commit -m ":lipstick: Fix indentation and style violations"
```

**Benefits of Logical Separation**:
- **Easier code review**: Reviewers can focus on one type of change at a time
- **Better git history**: Clear purpose for each commit makes history more readable
- **Safer rollbacks**: Can revert specific changes without affecting unrelated improvements
- **Cleaner cherry-picking**: Individual logical changes can be applied to other branches easily

**Tools for Logical Commits**: See [Selective Change Staging](#selective-change-staging) for detailed usage of `git add -p` and `git add -i`.

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

#### HEREDOC Usage for Commit Messages

**Recommended Approach**: Use HEREDOC for proper formatting and multi-line commit messages:

```bash
git commit -m "$(cat <<'EOF'
:hammer: Implement new feature with proper architecture

This commit adds the following improvements:
- Feature implementation with clean separation of concerns  
- Updated error handling for edge cases
- Added comprehensive test coverage

Technical details:
- Used dependency injection pattern for better testability
- Implemented proper logging for debugging purposes

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Benefits of HEREDOC Approach**:
- **Proper formatting**: Preserves line breaks and indentation in commit messages
- **Quote handling**: Eliminates issues with quotes and special characters in commit messages
- **Multi-line support**: Enables complex commit messages with detailed explanations
- **Consistency**: Ensures consistent formatting across different shells and environments
- **Template compliance**: Maintains the required Claude Code footer format

**Important Notes**:
- Always use `'EOF'` (quoted) to prevent variable expansion within the HEREDOC
- The `$(cat <<'EOF' ... EOF)` pattern ensures proper shell parsing
- Avoid backticks or complex escaping which can cause shell interpretation issues

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
squash def5678 :recycle: Remove backward compatibility alias
pick ghi9012 :police_officer: Fix style violations
```

### Commit Splitting

```bash
# Split latest commit
git reset --soft HEAD^
git add -p  # Selectively stage changes
git commit -m ":police_officer: Fix Style/CommentedKeyword violations"
git add .
git commit -m ":recycle: Remove backward compatibility alias"
```

### Selective Change Staging

Use interactive staging to create logical commits when you have mixed changes:

```bash
# Stage only specific changes within file
git add -p file.rb

# Stage specific lines only (interactive mode)
git add -i
```

**Common Use Cases**:
- **Separating logic from style**: Stage functional changes separately from formatting
- **Splitting features**: Stage different features from the same file separately  
- **Bug fix isolation**: Stage bug fixes separately from unrelated improvements
- **Partial file commits**: Commit only the relevant parts of large file changes

**Interactive Options with `git add -p`**:
- `y` - Stage this change
- `n` - Don't stage this change
- `s` - Split this change into smaller parts
- `e` - Manually edit the change
- `q` - Quit without staging remaining changes

This approach supports the [Logical Commit Guidelines](#logical-commit-guidelines) by enabling precise control over what goes into each commit.

### File Addition Guidelines

```bash
# Explicit file path specification (recommended)
git add lib/factorix/new_file.rb
git add spec/new_test.rb

# Avoid automatic additions that may include untracked files
# DON'T use: git add -A (adds untracked files unintentionally)
# DON'T use: git add -u (may miss new files you want to include)
```

**Important Notes**:
- Always specify explicit file paths when adding files to prevent accidental commits
- `git add -A` includes untracked files which may include temporary or configuration files
- `git add -A` should not be used as it may commit untracked files unintentionally
- Use `git status` to verify what will be committed before running `git commit`

### Pre-Commit Quality Checks

For Ruby projects, always run code quality checks before committing:

```bash
# Check for code style violations
bundle exec rubocop

# Fix auto-correctable violations (optional)
bundle exec rubocop -a

# Run tests to ensure functionality
bundle exec rspec

# Verify changes before committing
git status
git diff --cached
```

**Best Practice Workflow**:
1. Make your code changes
2. Run `bundle exec rubocop` to check for violations
3. Fix any violations (use `rubocop -a` for auto-correctable issues)
4. Run tests to ensure nothing is broken
5. Use `git add` with explicit file paths
6. Commit with proper message format

**Important Notes**:
- RuboCop violations should be resolved before committing
- If violations require significant refactoring, create separate commits for fixes
- Always run tests after auto-corrections to ensure functionality is preserved

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

After modifying commit history that has already been pushed, you need to force push safely:

```bash
# Recommended: Safe force push with lease check
git push --force-with-lease

# Most secure: Force push with include check (Git 2.30+)
git push --force-with-lease --force-if-includes

# Alternative: Force push with specific reference
git push --force-with-lease origin feature-branch
```

**Force Push Safety Options**:

- **`--force-with-lease`**: Prevents overwriting work if someone else has pushed to the branch
- **`--force-if-includes`**: Additional safety check that ensures your local branch includes all remote commits
- **Never use**: `--force` (or `-f`) alone - it can overwrite others' work without warning

**When to Use Force Push**:
- After interactive rebase (`git rebase -i`)
- After amending commits (`git commit --amend`)
- After commit message fixes
- After squashing or splitting commits

**Safety Checklist Before Force Push**:
1. Ensure you're on the correct branch: `git branch --show-current`
2. Check what will be pushed: `git log origin/branch-name..HEAD --oneline`
3. Verify no one else is working on the branch
4. Use `--force-with-lease` or `--force-if-includes` instead of `--force`

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