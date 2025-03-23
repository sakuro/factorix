:warning: Work in progress :warning:

# Factorix

Factorix is a command-line tool for managing Factorio MODs and launching the game.
It provides a simple interface for enabling, disabling, and listing MODs, as well as
launching Factorio with various options.

## Features

- Display information about your Factorio installation
- Launch Factorio with custom arguments
- List all installed MODs with different output formats
- Enable and disable MODs easily
- Download MODs from the Factorio MOD Portal
- Dump MOD settings in TOML format

## Usage

Factorix provides several commands to help you manage your Factorio MODs and launch
the game.

### Info Command

Display information about your Factorio installation:

```bash
factorix info
```

This command shows:

- Executable path
- User directory
- Data directory
- MOD directory
- Script output directory

### Launch Command

Launch Factorio:

```bash
factorix launch [options] [-- game_args]
```

Options:
- `--wait`, `-w`: Wait for the game to finish before returning to the command line

You can pass additional arguments to the Factorio executable by adding them after `--`:

```bash
factorix launch -- --dump-icon-sprites
factorix launch --wait -- --mod-directory /path/to/mods
```

The `--wait` option is useful when you want to run commands after the game exits:

```bash
factorix launch --wait && echo "Game has exited"
```

### MOD Management

#### List MODs

List all MODs under the management of the game:

```bash
factorix mod list [options]
```

Options:
- `--format FORMAT`: Output format (csv, markdown)

By default, this command outputs just the MOD names. With the `--format` option, you
can get more detailed information in CSV or Markdown table format.

#### Download a MOD

Download a MOD from the Factorio MOD Portal:

```bash
factorix mod download MOD_NAME [options]
```

Options:
- `--version VERSION`: Specific version to download (defaults to latest)
- `--output-directory DIR`: Directory to save the downloaded MOD file (defaults to current directory)
- `--quiet`: Suppress progress output during download

This command will:
1. Download the specified version (or latest if not specified)
2. Save the MOD file to the specified directory (or current directory if not specified)

Example usage:
```bash
# Download the latest version of a MOD
factorix mod download even-distribution

# Download a specific version
factorix mod download even-distribution --version 1.0.0

# Download to a specific directory
factorix mod download even-distribution --output-directory /path/to/mods

# Download quietly without progress bar
factorix mod download even-distribution --quiet
```

#### Enable a MOD

Enable a specific MOD:

```bash
factorix mod enable MOD_NAME [options]
```

Options:
- `--verbose`: Print more information during the operation

#### Disable a MOD

Disable a specific MOD:

```bash
factorix mod disable MOD_NAME [options]
```

Options:
- `--verbose`: Print more information during the operation

#### Dump MOD Settings

Dump MOD settings in TOML format:

```bash
factorix mod settings dump
```

This command reads the mod-settings.dat file from your Factorio MODs directory and outputs its contents in TOML format. This can be useful for inspecting or backing up your MOD settings.

If the settings file doesn't exist, an error message will be displayed.

## License

Factorix is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT). Copyright (c) 2025 OZAWA Sakuro.
