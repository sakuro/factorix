# :gear: Factorix

A Ruby gem for managing Factorio MODs, providing both a command-line interface and a library API for programmatic MOD management.

## Overview

Factorix simplifies Factorio MOD management by providing:
- A CLI tool for everyday MOD operations
- A library API for building custom MOD management tools
- Automatic dependency resolution and validation
- JSON-based MOD settings export/import
- Save file synchronization capabilities

## Features

- **MOD Discovery & Download**: List, search, and download MODs from the Factorio MOD Portal
- **Dependency Management**: Automatic dependency resolution and validation with graph-based analysis
- **MOD State Management**: Enable/disable MODs with automatic handling of dependencies and dependents
- **Installation & Uninstallation**: Install MODs directly from the portal or uninstall existing MODs
- **Save File Sync**: Synchronize MOD states and startup settings from Factorio save files
- **Settings Management**: Export/import MOD settings in JSON format
- **MOD Portal Integration**: Upload new MODs or update existing ones, edit metadata
- **Game Control**: Launch Factorio from the command line
- **Cross-platform Support**: Works on Windows, Linux, macOS, and WSL

## Requirements

- Ruby >= 3.2
- Factorio API Key (required for uploading MODs and editing MOD metadata)
  - Obtain your API key from [Factorio Profile](https://factorio.com/profile)

## Setup

For uploading MODs or editing MOD metadata, set the `FACTORIO_API_KEY` environment variable:

```bash
export FACTORIO_API_KEY=your_api_key_here
```

API key is not required for downloading, installing, or managing local MODs.

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
- `user_dir` - Path to Factorio user directory (MODs, saves, settings)
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

Run `factorix --help` to see available commands, or `factorix <command> --help` for command-specific usage and examples.

For detailed CLI documentation, see [doc/components/cli.md](doc/components/cli.md).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sakuro/factorix.

For development setup and detailed contribution guidelines, please see [DEVELOPMENT.md](DEVELOPMENT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

Copyright (c) 2025 OZAWA Sakuro

## Author

OZAWA Sakuro
