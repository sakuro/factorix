# Factorix

A Ruby gem for managing Factorio mods, providing both a command-line interface and a library API for programmatic mod management.

## Overview

Factorix simplifies Factorio mod management by providing:
- A CLI tool for everyday mod operations
- A library API for building custom mod management tools
- Automatic dependency resolution and validation
- JSON-based mod settings export/import
- Save file synchronization capabilities

## Features

- **MOD Discovery & Download**: List, search, and download mods from the Factorio Mod Portal
- **Dependency Management**: Automatic dependency resolution and validation with graph-based analysis
- **MOD State Management**: Enable/disable mods with automatic handling of dependencies and dependents
- **Installation & Uninstallation**: Install mods directly from the portal or uninstall existing mods
- **Save File Sync**: Synchronize MOD states and startup settings from Factorio save files
- **Settings Management**: Export/import mod settings in JSON format
- **MOD Portal Integration**: Upload new mods or update existing ones, edit metadata
- **Game Control**: Launch Factorio from the command line
- **Cross-platform Support**: Works on Windows, Linux, macOS, and WSL

## Requirements

- Ruby >= 3.2
- Factorio API Key (required for uploading mods and editing mod metadata)
  - Obtain your API key from [Factorio Profile](https://factorio.com/profile)

## Installation

Install the gem:

```bash
gem install factorix
```

Or add to your Gemfile:

```ruby
gem 'factorix'
```

Then execute:

```bash
bundle install
```

## Setup

For uploading mods or editing mod metadata, set the `FACTORIO_API_KEY` environment variable:

```bash
export FACTORIO_API_KEY=your_api_key_here
```

API key is not required for downloading, installing, or managing local mods.

## Configuration

### Path Configuration

Factorix auto-detects Factorio installation paths for Steam installations. For other environments or to override the detected paths, create a configuration file.

**Find configuration file location:**
```bash
factorix path --json | jq -r '.factorix_config_path'
```

**Create configuration file:**
```bash
# Copy example configuration
cp example/config.rb ~/.config/factorix/config.rb

# Edit the configuration
$EDITOR ~/.config/factorix/config.rb
```

**Configurable paths:**
- `executable_path` - Path to Factorio executable
- `user_dir` - Path to Factorio user directory (mods, saves, settings)
- `data_dir` - Path to Factorio data directory

**Example configuration:**
```ruby
Factorix::Application.configure do |config|
  config.runtime.executable_path = "/Applications/Factorio.app/Contents/MacOS/factorio"
  config.runtime.user_dir = "#{Dir.home}/Library/Application Support/factorio"
  config.runtime.data_dir = "/Applications/Factorio.app/Contents/data"
end
```

See `example/config.rb` for platform-specific examples and additional configuration options.

## Usage

### General Commands

Display version information:
```bash
factorix version
```

Show Factorio and Factorix-related paths:
```bash
factorix path
```

Launch Factorio:
```bash
factorix launch
```

### MOD Management

Check MOD dependencies:
```bash
factorix mod check
```

Install MODs and their dependencies from Factorio MOD Portal:
```bash
factorix mod install MOD_NAME
factorix mod install MOD_NAME@VERSION
factorix mod install MOD_NAME@latest
factorix mod install -j 8 MOD1 MOD2  # Use 8 parallel downloads
```

Enable MODs (recursively enables dependencies):
```bash
factorix mod enable MOD_NAME1 MOD_NAME2
```

Disable MODs (recursively disables dependents):
```bash
factorix mod disable MOD_NAME1 MOD_NAME2
```

Uninstall MODs:
```bash
factorix mod uninstall MOD_NAME
factorix mod uninstall MOD_NAME@VERSION
factorix mod uninstall --all  # Uninstall all MODs
```

Download a MOD:
```bash
factorix mod download MOD_NAME
factorix mod download MOD_NAME@VERSION
```

Upload MOD to Factorio MOD Portal:
```bash
factorix mod upload MOD_FILE.zip
factorix mod upload MOD_FILE.zip --description "Description" --category "category-name"
```

Edit MOD metadata on Factorio MOD Portal:
```bash
factorix mod edit MOD_NAME --description "New description"
factorix mod edit MOD_NAME --title "New Title" --category "new-category"
```

Manage MOD images on Factorio MOD Portal:
```bash
# List all images for a MOD
factorix mod image list MOD_NAME

# Add an image to a MOD
factorix mod image add MOD_NAME screenshot.png

# Edit MOD's image list (reorder or remove images)
factorix mod image edit MOD_NAME abc123 def456 ghi789
```

Sync MOD states and startup settings from a save file:
```bash
factorix mod sync SAVE_FILE.zip
factorix mod sync -j 8 SAVE_FILE.zip  # Use 8 parallel downloads
```

### MOD Settings

Export mod settings to JSON:
```bash
factorix mod settings dump --output settings.json
factorix mod settings dump  # Output to stdout
```

Import mod settings from JSON:
```bash
factorix mod settings restore --input settings.json
factorix mod settings restore  # Read from stdin
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sakuro/factorix.

For development setup and detailed contribution guidelines, please see [DEVELOPMENT.md](DEVELOPMENT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

Copyright (c) 2025 OZAWA Sakuro

## Author

OZAWA Sakuro
