# Unclassified Guidelines

This file contains guidelines and procedures that haven't been classified into the main documentation structure yet. Content here should eventually be moved to appropriate files.

## Advanced Git Operations

### Multiple Commit Integration

```bash
# Integrate feature commits and style fixes
git reset --soft HEAD~2
git commit -m ":hammer: Feature implementation with style fixes

- Implement main feature functionality
- Fix related RuboCop violations
- Update tests and documentation"
```

### Commit Order Changes

```bash
git rebase -i HEAD~4
# Change order in editor
pick ghi9012 :hammer: Main feature
pick def5678 :lipstick: Style fixes
pick abc1234 :test_tube: Tests
pick jkl3456 :memo: Documentation
```

### Emergency Fix Response

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

### Pre-push Hook Response

```bash
# Prepare for automatic checks before push
git add .
git commit -m ":lipstick: Pre-push fixes"
git push
# RuboCop/RSpec executed by hooks
```

### Failure Response

```bash
# Fix when CI fails
git add .
git commit --amend --no-edit
git push --force-with-lease
```

## Review Response Guidelines

### Review Comment Response Template

```markdown
@reviewer Thanks for the review! Regarding the [specific concern]:

While I understand the concern about [issue], I've chosen to keep the current implementation for the following reasons:

1. **Technical Reason**: Detailed explanation of technical choice
2. **Context Consideration**: Explanation of specific context (e.g., CLI vs library)
3. **Trade-off Analysis**: Explanation of trade-offs considered

The current implementation prioritizes [priority] over [alternative], which I believe is appropriate for this use case.
```

## Development Workflow Integration Notes

As part of the standard development workflow, RuboCop verification is essential:

1. **Before Committing**: Always run `bundle exec rubocop` to check for violations
2. **During PR Review**: Ensure all RuboCop issues are resolved or properly documented  
3. **Continuous Integration**: RuboCop checks should be part of the CI pipeline
4. **Code Quality**: RuboCop helps maintain consistent code style and catches potential issues

This ensures consistent code quality and maintainability across the project. For detailed RuboCop response procedures, refer to the Code Quality Management guide.

## TODO: Content Classification

The following content in this file should eventually be moved to:

- **Advanced Git Operations** → Consider moving to `git-workflow.md` under an "Advanced Operations" section
- **CI/CD Integration** → Consider moving to `code-quality.md` or creating a separate CI/CD guide
- **Review Response Guidelines** → Consider moving to `git-workflow.md` under PR management
- **Development Workflow Integration** → Already covered in `code-quality.md`, this section may be redundant