# Factorix Project Structure

This document provides an overview of the Factorix project structure.

## Root Directory

The root directory contains essential project files and configuration:

- `CHANGELOG.md` - Version history and release notes
- `CLAUDE.md` - Project guidelines and instructions for AI assistance
- `Gemfile` / `Gemfile.lock` - Ruby dependency management
- `LICENSE.txt` - Project license
- `README.md` - Main project documentation
- `Rakefile` - Ruby task definitions
- `factorix.gemspec` - Gem specification
- `mise.toml` - Development environment configuration

## Main Directories

### `bin`
Contains executable files for the Factorix command-line interface.

### `exe`
- `factorix` - Main executable file

### `lib`
Core library implementation organized in modules:

- `factorix.rb` - Main entry point
- `factorix/` - Core modules:
  - `cache/` - Caching functionality
    - `file_system.rb` - File system-based cache implementation
  - `cli/` - Command-line interface
    - `commands/` - CLI command implementations
      - `info.rb` - Information commands
      - `launch.rb` - Game launch functionality
      - `mod/` - Mod management commands
        - `disable.rb` - Mod disabling
        - `download.rb` - Mod downloading
        - `enable.rb` - Mod enabling
        - `list.rb` - Mod listing
        - `settings/` - Mod settings management
          - `dump.rb` - Settings dump functionality
  - `credential.rb` - Authentication and credentials
  - `downloader.rb` - File download functionality
  - `errors.rb` - Error definitions and handling
  - `http_client.rb` - HTTP client implementation
  - `mod.rb` - Mod entity and operations
  - `mod_context.rb` - Mod context management
  - `mod_list.rb` - Mod list management
  - `mod_portal/` - Factorio Mod Portal integration
    - `api.rb` - API client
    - `types.rb` - Type definitions
  - `mod_settings.rb` - Mod settings management
  - `mod_state.rb` - Mod state tracking
  - `progress/` - Progress tracking
    - `bar.rb` - Progress bar implementation
  - `retry_strategy.rb` - Retry logic for operations
  - `runtime.rb` - Runtime environment detection
  - `runtime/` - Platform-specific runtime implementations
    - `linux.rb` - Linux platform support
    - `mac_os.rb` - macOS platform support
    - `windows.rb` - Windows platform support
    - `wsl.rb` - Windows Subsystem for Linux support
  - `ser_des.rb` - Serialization/deserialization
  - `ser_des/` - SerDes implementations
    - `deserializer.rb` - Deserialization logic
    - `serializer.rb` - Serialization logic
    - `version24.rb` - Version 24 format support
    - `version64.rb` - Version 64 format support
  - `version.rb` - Version information

### `sig`
Ruby type signatures (RBS files) for static type checking:
- Mirrors the `lib` directory structure with `.rbs` files
- Provides type definitions for all classes and methods

### `spec`
Test suite using RSpec:
- `factorix/` - Tests organized by module structure
- `fixtures/` - Test data and fixtures
  - `mod-list/` - Sample mod list data
  - `vcr_cassettes/` - HTTP request/response recordings for testing
- `spec_helper.rb` - Test configuration

### `tasks`
Rake task definitions:
- `clean.rake` - Cleanup tasks
- `rubocop.rake` - Code style checking tasks

### `docs`
Project documentation:
- `design/` - Design documents
  - `exceptions.md` - Exception handling design
  - `mod_dependency.md` - Mod dependency management design
  - `mod_publish_upload.md` - Mod publishing and upload design

### Generated Documentation

#### `doc`
YARD-generated API documentation:
- HTML documentation for all classes and methods
- Organized by namespace and class hierarchy

#### `coverage`
Test coverage reports:
- HTML coverage reports
- Assets and styling for coverage visualization

### `vendor`
Third-party dependencies and vendored code.

## Configuration Files

### `.claude/`
AI assistance configuration (referenced from CLAUDE.md):
- `language-guidelines.md` - Language usage guidelines
- `file-format-guidelines.md` - File format standards

## Architecture Overview

Factorix is a Ruby gem that provides a command-line interface for managing Factorio mods. The architecture follows these key patterns:

1. **CLI Layer** (`lib/factorix/cli`): Command-line interface handling user input
2. **Core Logic** (`lib/factorix`): Business logic and domain models
3. **Platform Abstraction** (`lib/factorix/runtime`): Platform-specific implementations
4. **External Integration** (`lib/factorix/mod_portal`): Factorio Mod Portal API integration
5. **Persistence** (`lib/factorix/cache`, `lib/factorix/ser_des`): Data storage and serialization
6. **Utilities** (`lib/factorix/progress`, `lib/factorix/http_client`): Supporting functionality

The project follows Ruby conventions with comprehensive test coverage and type definitions for maintainability.