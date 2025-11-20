# Factorix - Project Overview

## Overview

Factorix is a comprehensive CLI tool and Ruby library for managing Factorio mods.

## Purpose

Provide both command-line and programmatic interfaces for Factorio mod management, including dependency resolution, settings management, and MOD Portal integration.

## Features

### 1. Game Information and Control
- Retrieve Factorio installation paths and directories
- Launch Factorio with custom options
- Prevent multiple simultaneous launches
- Automatic process management for certain commands

### 2. MOD Management
- **Discovery**: List and search mods from MOD Portal
- **Installation**: Install mods with automatic dependency resolution
- **State Management**: Enable/disable mods with dependency tracking
- **Validation**: Check dependency integrity (`mod check`)
- **Synchronization**: Sync MOD states from save files (`mod sync`)
- **Uninstallation**: Remove mods from mod directory

### 3. Dependency Resolution
- **Graph-based resolution**: Uses directed acyclic graph (DAG) with topological sorting
- **Cyclic dependency detection**: Detects and reports circular dependencies
- **Incompatibility checking**: Validates bidirectional incompatibilities
- **Version requirements**: Supports complex version constraints

### 4. Settings Management
- Export/import mod settings in JSON format
- Binary format support (mod-settings.dat)
- Three setting types: startup, runtime-global, runtime-per-user

### 5. Save File Analysis
- Extract MOD information from Factorio save files
- Parse startup settings from save files
- Support for both level.dat0 and level-init.dat formats

### 6. MOD Portal Integration
- **Upload**: Publish new MODs or updates
- **Edit**: Modify MOD metadata
- **Download**: Fetch MOD files with caching
- **Authentication**: API key-based authentication

## Key Technical Features

- **Cross-platform**: Windows, Linux, macOS, WSL support
- **Dependency Injection**: Clean architecture using dry-rb
- **HTTP Caching**: File system-based cache with decorator pattern
- **Retry Strategy**: Automatic retry for network operations
- **Progress Tracking**: Multi-presenter progress bars for downloads
- **Type Safety**: RBS type signatures
- **Concurrent Downloads**: Parallel processing for bulk operations

## Related Documentation

- [Architecture](architecture.md) - Overall system design
- [Technology Stack](technology-stack.md) - Technologies and libraries used
- [Component Details](components/) - Detailed design of each component
