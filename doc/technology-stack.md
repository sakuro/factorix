# Technology Stack

## Candidates Extracted from Old Project

### Required Runtime Dependencies

- **Zeitwerk** (>= 2.7.1)
  - Purpose: Auto-loading
  - Assessment: ✅ Required

- **dry-cli** (>= 1.2.0)
  - Purpose: CLI framework
  - Assessment: ✅ Recommended (concise command registration)

- **dry-container**
  - Purpose: Dependency container
  - Assessment: ✅ Required (used in combination with dry-auto_inject)

- **dry-auto_inject**
  - Purpose: Dependency injection (DI)
  - Assessment: ✅ Adopted (makes logger, cache management, etc. injectable)
  - Note: Used in combination with dry-container

- **dry-configurable** (>= 1.0)
  - Purpose: Application configuration management
  - Assessment: ✅ Adopted (enables definition and customization of settings)
  - Config file: XDG-compliant (`$XDG_CONFIG_HOME/factorix/config.rb`, defaults to `~/.config/factorix/config.rb`)
  - Format: Ruby DSL

- **retriable** (>= 3.1.2)
  - Purpose: Retry logic
  - Assessment: ✅ Recommended (essential for network operations)

- **ruby-progressbar** (>= 1.13.0)
  - Purpose: Progress display
  - Assessment: ✅ Recommended (UX improvement)

- **tint_me**
  - Purpose: Terminal output colorization and text decoration
  - Assessment: ✅ Adopted (UX improvement)
  - Features: Zeitwerk integration, uses dry-schema/dry-types, composable styles
  - Performance: Pre-composition recommended (define once, use many)

- **dry-core** (>= 1.1.0)
  - Purpose: Utilities
  - Assessment: 🤔 May come automatically as dependency of dry-cli

### Output Format Related

- **csv** (>= 3.2.8)
  - Purpose: CSV output
  - Assessment: ✅ Standard library, no problem

- **perfect_toml** (>= 0.9.0)
  - Purpose: TOML serialization (exclusively for MOD settings dump/load)
  - Assessment: ✅ Adopted (most complete implementation)

### Development Tools

- **RuboCop**
  - Purpose: Code style enforcement
  - Assessment: ✅ Already integrated (docquet configuration)

- **RBS**
  - Purpose: Type signatures
  - Assessment: ✅ Already integrated

- **YARD**
  - Purpose: Documentation generation
  - Assessment: ✅ Already integrated

- **RSpec**
  - Purpose: Testing framework
  - Assessment: ✅ Already integrated

- **WebMock**
  - Purpose: HTTP request stubbing and mocking
  - Assessment: ✅ Recommended (essential for HTTP testing)

- **SimpleCov**
  - Purpose: Coverage measurement
  - Assessment: ✅ Already integrated

## Standard Library Usage Policy

- **HTTP Client**: Use `net/http`
  - Also use `URI` class
  - Assessment: ✅ Standard library is sufficient

- **File Processing**: Use `Pathname` class
  - Unify with Pathname as much as possible
  - Assessment: ✅ Recommended

- **JSON Parser**: Standard library `json`
  - Assessment: ✅ Standard library is sufficient

- **ERB Templates**: Standard library `erb`
  - Assessment: ✅ Standard library is sufficient

## Related Documentation

- [Project Overview](overview.md)
- [Architecture](architecture.md)
