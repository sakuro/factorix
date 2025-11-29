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
- **dry-logger** (~> 1.2) - Logging
- **dry-core** (>= 1.1.0) - Utilities
- **retriable** (>= 3.1.2) - Retry logic for network operations
- **tty-progressbar** (~> 0.18) - Progress display with multi-bar support
- **tint_me** (~> 1.1) - Terminal text coloring
- **parslet** (~> 2.0) - PEG parser for dependency string parsing
- **rubyzip** (~> 3.2) - ZIP file handling for save file parsing
- **concurrent-ruby** (~> 1.0) - Parallel processing for concurrent MOD downloads

## Standard Library

- **net/http** / **URI** - HTTP client
- **Pathname** - File processing
- **json** - JSON parsing and MOD settings export/import
- **erb** (`ERB::Util.url_encode`) - URL encoding

## Development Tools

### Testing
- **RSpec** - Testing framework
- **WebMock** - HTTP request stubbing and mocking
- **SimpleCov** - Coverage measurement

### Debugging
- **debug** - Ruby debugger
- **ruby-lsp** - Ruby Language Server Protocol for IDE integration

### Code Quality
- **RuboCop** - Code style enforcement
  - `rubocop-performance` - Performance cops
  - `rubocop-rake` - Rake-specific cops
  - `rubocop-rspec` - RSpec-specific cops
  - `rubocop-thread_safety` - Thread safety cops
  - `docquet` - Shared RuboCop configuration

### Type Checking
- **Steep** - Static type checker for Ruby
- **RBS** - Ruby type signature files (in `sig/` directory)

### Documentation
- **YARD** - Documentation generation
  - `redcarpet` - Markdown rendering support

## Related Documentation

- [Project Overview](overview.md)
- [Architecture](architecture.md)
