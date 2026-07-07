# :gear: Factorix

A Ruby gem providing a CLI for Factorio MOD management, settings synchronization, and game control.

## Overview

Factorix simplifies Factorio MOD management by providing:
- A CLI tool for everyday MOD operations
- Automatic dependency resolution and validation
- JSON-based MOD settings export/import
- Save file synchronization capabilities

## Features

- **MOD Discovery & Download**: Search and download MODs from the Factorio MOD Portal
- **Dependency Management**: Automatic dependency resolution and validation with graph-based analysis
- **MOD State Management**: Enable/disable MODs with automatic handling of dependencies and dependents
- **Installation & Uninstallation**: Install MODs directly from the portal or uninstall existing MODs
- **Save File Sync**: Synchronize MOD states and startup settings from Factorio save files
- **Settings Management**: Export/import MOD settings in JSON format
- **Blueprint Conversion**: Decode/encode Factorio blueprint strings to/from JSON
- **MOD Portal Integration**: Upload new MODs or update existing ones, edit metadata
- **Game Control**: Launch Factorio from the command line
- **RCon**: Execute console commands and Lua scripts on a running Factorio server via RCon
- **Game Download**: Download Factorio game files (alpha, expansion, demo, headless)
- **Cross-platform Support**: Works on Windows, Linux, macOS, and WSL

## Requirements

- Ruby (non-EOL versions)
- Factorio API Key (required for uploading MODs and editing MOD metadata)
  - Obtain your API key from [Factorio Profile](https://factorio.com/profile)

## Setup

For uploading MODs or editing MOD metadata, set the `FACTORIO_API_KEY` environment variable:

```bash
export FACTORIO_API_KEY=your_api_key_here
```

API key is not required for managing local MODs.

For downloading MODs from the MOD Portal (including via `factorix mod install`) or downloading the game itself, service credentials are required. These are automatically loaded from `player-data.json` if you have logged into Factorio, or you can set `FACTORIO_USERNAME` and `FACTORIO_TOKEN` environment variables.

## Configuration

### Path Configuration

Factorix auto-detects Factorio installation paths for Steam installations. For other environments or to override the detected paths, create a configuration file.

**Find configuration file location:**
```bash
factorix path --json | jq -r .factorix_config_path
```

**Create configuration file:**
```bash
# Copy example configuration
cp example/config.toml ~/.config/factorix/config.toml

# Edit the configuration
$EDITOR ~/.config/factorix/config.toml
```

**Configurable paths:**
- `executable_path` - Path to Factorio executable
- `user_dir` - Path to Factorio user directory (MODs, saves, settings)
- `data_dir` - Path to Factorio data directory

**Example configuration:**
```toml
[runtime]
executable_path = "/Applications/Factorio.app/Contents/MacOS/factorio"
user_dir = "/Users/me/Library/Application Support/factorio"
data_dir = "/Applications/Factorio.app/Contents/data"
```

See [`example/config.toml`](example/config.toml) for platform-specific examples and additional configuration options.

**Alternative configuration path:**

You can specify a custom configuration file path using the `--config-path` option or `FACTORIX_CONFIG` environment variable:
```bash
# Using CLI option
factorix mod list --config-path=/path/to/config.toml

# Using environment variable
export FACTORIX_CONFIG=/path/to/config.toml
factorix mod list
```

**Migrating from the Ruby configuration file:** earlier versions used a Ruby
DSL at `~/.config/factorix/config.rb`. When Factorix finds one, it prints the
equivalent TOML — review it, save it as `config.toml`, and remove the old file.

## Usage

Run `factorix --help` to see available commands, or `factorix <command> --help` for command-specific usage and examples.

For detailed CLI documentation, run `factorix man` or see [`doc/components/cli.md`](doc/components/cli.md).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sakuro/factorix.

For development setup and detailed contribution guidelines, please see [`DEVELOPMENT.md`](DEVELOPMENT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

Copyright (c) 2025 OZAWA Sakuro
