# Factorix - Project Overview

## Overview

Factorix is a comprehensive CLI tool and Ruby library for managing Factorio MODs.

## Purpose

Provide both command-line and programmatic interfaces for Factorio MOD management, including dependency resolution, settings management, and MOD Portal integration.

## Features

### 1. Game Information and Control
- Retrieve Factorio installation paths and directories
- Launch Factorio with custom options
- Automatic process management for certain commands

### 2. MOD Management
- **Discovery**: List and search MODs from MOD Portal
- **Installation**: Install MODs with automatic dependency resolution
- **State Management**: Enable/disable MODs with dependency tracking
- **Validation**: Check dependency integrity (`mod check`)
- **Synchronization**: Sync MOD states from save files (`mod sync`)
- **Uninstallation**: Remove MODs from MOD directory

### 3. Dependency Resolution
- **Graph-based resolution**: Uses directed acyclic graph (DAG) with topological sorting
- **Cyclic dependency detection**: Detects and reports circular dependencies
- **Incompatibility checking**: Validates bidirectional incompatibilities
- **Version requirements**: Supports complex version constraints

### 4. Settings Management
- Export/import MOD settings in JSON format

### 5. Save File Analysis
- Extract MOD information from Factorio save files
- Parse startup settings from save files

### 6. MOD Portal Integration
- **Upload**: Publish new MODs or updates
- **Edit**: Modify MOD metadata
- **Download**: Fetch MOD files with caching
- **Authentication**: API key-based authentication

## Key Technical Features

- **Dependency Injection**: Clean architecture using dry-rb
- **HTTP Caching**: File system-based cache with decorator pattern
- **Retry Strategy**: Automatic retry for network operations
- **Progress Tracking**: Multi-presenter progress bars for downloads
- **Concurrent Downloads**: Parallel processing for bulk operations

## Related Documentation

- [Architecture](architecture.md) - Overall system design
- [Technology Stack](technology-stack.md) - Technologies and libraries used
- [Component Details](components/) - Detailed design of each component
