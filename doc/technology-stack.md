# Technology Stack

## Runtime Dependencies

- **Zeitwerk** (>= 2.7.1) - Auto-loading
- **dry-cli** (>= 1.2.0) - CLI framework
- **dry-container** - Dependency container
- **dry-auto_inject** - Dependency injection (used with dry-container)
- **dry-configurable** (>= 1.0) - Application configuration management
  - Config file: XDG-compliant (`$XDG_CONFIG_HOME/factorix/config.rb`, defaults to `~/.config/factorix/config.rb`)
  - Format: Ruby DSL
- **dry-events** (~> 1.1) - Event system for progress notification
- **dry-core** (>= 1.1.0) - Utilities
- **retriable** (>= 3.1.2) - Retry logic for network operations
- **tty-progressbar** (~> 0.18) - Progress display with multi-bar support
- **parslet** (~> 2.0) - PEG parser for dependency string parsing
- **rubyzip** (~> 3.2) - ZIP file handling for save file parsing
- **concurrent-ruby** (~> 1.0) - Parallel processing for concurrent mod downloads

## Standard Library

- **net/http** / **URI** - HTTP client
- **Pathname** - File processing
- **json** - JSON parsing and MOD settings export/import
- **erb** (`ERB::Util.url_encode`) - URL encoding

## Development Tools

- **RSpec** - Testing framework
- **WebMock** - HTTP request stubbing and mocking
- **SimpleCov** - Coverage measurement
- **RuboCop** - Code style enforcement
- **Steep** - Static type checking
- **YARD** - Documentation generation

## Related Documentation

- [Project Overview](overview.md)
- [Architecture](architecture.md)
