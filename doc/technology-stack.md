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

- **tty-progressbar** (~> 0.18)
  - Purpose: Progress display
  - Assessment: ✅ Adopted (multi-bar support, UX improvement)

- **parslet** (~> 2.0)
  - Purpose: PEG parser (dependency string parsing)
  - Assessment: ✅ Adopted (complex dependency syntax parsing)

- **rubyzip** (~> 3.2)
  - Purpose: ZIP file handling (save file parsing)
  - Assessment: ✅ Adopted (Factorio save file extraction)

- **concurrent-ruby** (~> 1.0)
  - Purpose: Parallel processing
  - Assessment: ✅ Adopted (concurrent mod downloads in install, download, and sync commands)

- **dry-events** (~> 1.1)
  - Purpose: Event system
  - Assessment: ✅ Adopted (progress notification)

- **dry-core** (>= 1.1.0)
  - Purpose: Utilities
  - Assessment: 🤔 May come automatically as dependency of dry-cli

### Output Format Related

- **json** (standard library)
  - Purpose: MOD settings export/import
  - Assessment: ✅ Standard library is sufficient

### Development Tools

- **RuboCop**
  - Purpose: Code style enforcement
  - Assessment: ✅ Already integrated (docquet configuration)

- **Steep**
  - Purpose: Static type checking
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

- **URL Encoding**: Standard library `erb` (`ERB::Util.url_encode`)
  - Assessment: ✅ Standard library is sufficient

## Related Documentation

- [Project Overview](overview.md)
- [Architecture](architecture.md)
