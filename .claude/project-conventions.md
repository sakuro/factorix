# Project Conventions

## Factorix-Specific Guidelines

This document contains conventions and guidelines specific to the Factorix project.

## Development Environment

### Ruby Environment
- Use the Ruby version specified in `.ruby-version`
- Bundle dependencies with `bundle install`
- Run tests with `bundle exec rspec`

### Development Tools
- **RuboCop**: Code style enforcement
- **Steep**: Type checking (if applicable)
- **YARD**: Documentation generation
- **RSpec**: Testing framework

## Project Structure

### Library Organization
- Core functionality in `lib/factorix/`
- Type signatures in `sig/factorix/` (if using RBS)
- Tests in `spec/`
- Documentation in appropriate markdown files

### Naming Conventions
- Use snake_case for file names
- Use PascalCase for class names
- Use SCREAMING_SNAKE_CASE for constants
- Use descriptive names that reflect functionality

## Error Handling
- Use appropriate exception hierarchy
- Provide meaningful error messages
- Include relevant context in exceptions

## Testing Conventions
- Write comprehensive test coverage
- Use descriptive test names
- Group related tests logically
- Test both success and failure cases

## Documentation Requirements
- Document public APIs with YARD
- Include usage examples where appropriate
- Keep documentation up-to-date with code changes
- Use English for all technical documentation

## Release Management
- Follow semantic versioning
- Tag releases appropriately
- Maintain changelog
- Ensure all tests pass before release

## CI/CD Integration
- All commits should pass RuboCop checks
- All tests must pass
- Type checking should pass (if applicable)
- Documentation should build successfully

## Performance Considerations
- Profile code when performance is critical
- Use appropriate data structures
- Consider memory usage for large datasets
- Benchmark significant changes

## Security Guidelines
- Validate all inputs
- Handle sensitive data appropriately
- Follow secure coding practices
- Regular security updates for dependencies

## Dependency Management
- Keep dependencies up-to-date
- Justify new dependencies
- Use appropriate version constraints
- Regular security audits

## Special Instructions

### Development Memories
- Display progress messages when starting and completing the loading of CLAUDE.md file and referenced files

### Modification Guidelines
- If an instruction does not fit into existing categories, create a new file in the .claude directory and reference it from CLAUDE.md
- Keep project-specific conventions in this file
- General development standards should go in development-standards.md