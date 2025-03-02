:warning: Work in progress :warning:

# Factorix

Factorix is a command-line tool for managing Factorio mods and launching the game.
It provides a simple interface for enabling, disabling, and listing mods, as well as
launching Factorio with various options.

## Features

- Display information about your Factorio installation
- Launch Factorio with custom arguments
- List all installed mods with different output formats
- Enable and disable mods easily
- Dump mod settings in TOML format

## Usage

Factorix provides several commands to help you manage your Factorio mods and launch
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
- Mod directory
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

### Mod Management

#### List Mods

List all mods under the management of the game:

```bash
factorix mod list [options]
```

Options:
- `--format FORMAT`: Output format (csv, markdown)

By default, this command outputs just the mod names. With the `--format` option, you
can get more detailed information in CSV or Markdown table format.

#### Enable a Mod

Enable a specific mod:

```bash
factorix mod enable MOD_NAME [options]
```

Options:
- `--verbose`: Print more information during the operation

#### Disable a Mod

Disable a specific mod:

```bash
factorix mod disable MOD_NAME [options]
```

Options:
- `--verbose`: Print more information during the operation

#### Dump Mod Settings

Dump mod settings in TOML format:

```bash
factorix mod settings dump
```

This command reads the mod-settings.dat file from your Factorio mods directory and outputs its contents in TOML format. This can be useful for inspecting or backing up your mod settings.

If the settings file doesn't exist, an error message will be displayed.

## License

Factorix is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT). Copyright (c) 2025 OZAWA Sakuro.
