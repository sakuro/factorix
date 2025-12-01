# CLI Command Details

## Basic Structure

- Register commands using dry-cli `Registry`
- Commands are placed under `CLI::Commands` module
- **Output Guidelines**: Commands use `say()` for human-readable messages (respects `--quiet`) and `puts()` for structured data output (always outputs). See [CLI Output Guidelines](../../DEVELOPMENT.md#cli-output-guidelines) for detailed conventions.

## Global Options

The following options are available for all commands:

| Option | Description |
|--------|-------------|
| `-c`, `--config-path=VALUE` | Path to configuration file |
| `--log-level=VALUE` | Set log level: debug, info, warn, error, fatal |
| `-q`, `--quiet` | Suppress non-essential output |
| `-h`, `--help` | Print help information |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `FACTORIX_CONFIG` | Path to configuration file. Overrides the default location. |

See [Application Configuration](application.md) for configuration file loading priority.

## Command List

### Version

Display Factorix version.

**Output**: Current version of the Factorix gem

### Man

Display the Factorix manual page using the system's man command.

**Requirements**: Requires the `man` command to be available on the system.

**Error**: Exits with error if `man` command is not available.

### Path

Display all Factorio and Factorix paths.

**Options**:
- `--json` - Output in JSON format

**Output**: Table format by default, JSON format with `--json` option

**Included paths**:
- `executable_path` - Factorio executable file
- `data_dir` - Factorio data directory
- `user_dir` - Factorio user directory
- `mod_dir` - MODs directory
- `save_dir` - Saves directory
- `script_output_dir` - Script output directory
- `mod_list_path` - mod-list.json file
- `mod_settings_path` - mod-settings.dat file
- `player_data_path` - player-data.json file
- `lock_path` - Lock file (indicates if game is running)
- `current_log_path` - Current log file
- `previous_log_path` - Previous log file
- `factorix_cache_dir` - Factorix cache directory
- `factorix_config_path` - Factorix configuration file
- `factorix_log_path` - Factorix log file

### Cache::Stat

Display cache statistics.

**Options**:
- `--json` - Output in JSON format

**Output**: Text format by default showing:
- Directory path
- TTL (time-to-live) setting
- Max file size limit
- Compression threshold
- Entry counts (valid/total)
- Size statistics (total, avg)
- Age statistics (oldest, newest, avg)
- Stale lock count

**Use case**: Monitor cache usage and health

### Cache::Evict

Remove cache entries.

**Arguments**:
- `caches` - Cache names to evict (download, api, info_json). If not specified, operates on all caches.

**Options** (mutually exclusive, one required):
- `--all` - Remove all entries
- `--expired` - Remove expired entries only
- `--older-than AGE` - Remove entries older than AGE (e.g., 30s, 5m, 2h, 7d)

**Examples**:
```bash
factorix cache evict --expired              # Remove expired entries from all caches
factorix cache evict api --all              # Remove all entries from api cache
factorix cache evict download --older-than 7d  # Remove entries older than 7 days
```

**Use case**: Free up disk space or clear stale cache data

### Completion

Generate shell completion script.

**Arguments**:
- `shell` (optional) - Shell type: zsh, bash, fish. Defaults to current shell from SHELL environment variable.

**Output**: Shell completion script that should be evaluated to enable command-line completion.

**Examples**:
```bash
# Auto-detect shell
eval "$(factorix completion)"

# Specify shell explicitly
eval "$(factorix completion zsh)"
eval "$(factorix completion bash)"
factorix completion fish | source  # fish shell
```

**Use case**: Enable tab completion for factorix commands

### Launch

Launch the game.

**Features**:
- Pass options to Factorio (after `--`)
- Automatically wait for termination for certain commands

### MOD::Enable

Enable the specified MOD.

### MOD::Disable

Disable the specified MOD(s).

**Options**:
- `--all` - Disable all MODs except base (includes expansion MODs)

### MOD::Download vs MOD::Install

#### Download Command

**Options**:
- `-d`, `--directory` - Download directory (default: current directory)
- `-r`, `--recursive` - Include required dependencies recursively
- `-j`, `--jobs` - Number of parallel downloads (default: 4)

**Behavior**:
- Download to any location (specify with `--directory` or `-d`, defaults to current directory)
- Dependencies are not included by default (use `--recursive` or `-r` to include required dependencies)
- Don't modify `mod-list.json`
- Use cache

**Purpose**: When only retrieving MOD files is the goal

#### Install Command

**Options**:
- `-j`, `--jobs` - Number of parallel downloads (default: 4)

**Workflow**:

##### 1. Information Gathering Phase (no destructive operations)

- Retrieve MOD information (including info.json) from Portal API
- Analyze dependencies (`MODDependencies`)
- Recursively collect required dependencies
- Verify version requirements

##### 2. Validation Phase (no destructive operations)

- Incompatibility check (conflict with existing MODs)
- Circular dependency check
- Version conflict check
- Report error and abort immediately if any errors

##### 3. Execution Phase (only after successful validation)

- Recursively download required dependency MODs
- Place in `Runtime#mod_dir`
- Add to `mod-list.json` (in enabled state)

**Error Example**:
```
Error: Cannot install some-mod@1.2.0
  - Incompatible with existing MOD: conflicting-mod@2.0.0
  - Required dependency base >= 2.0.0 not satisfied (current: 1.1.0)
```

#### Uninstall Command

**Workflow**:

##### 1. Reverse Dependency Check

- Verify that no other enabled MODs depend on this MOD
- Abort with error if depended upon

##### 2. Deletion Execution

- Remove from `mod-list.json`
- Delete files from `Runtime#mod_dir`

**Error Example**:
```
Error: Cannot uninstall some-library-mod
  - Required by: some-mod@1.2.0, another-mod@3.0.0
  - Uninstall these mods first, or disable them
```

### MOD::Update

Update installed MODs to their latest versions.

**Options**:
- `-j`, `--jobs` - Number of parallel downloads (default: 4)

**Workflow**:

##### 1. Check Phase

- Fetch latest version information from Portal API
- Compare with currently installed versions
- Identify MODs with available updates

##### 2. Confirmation Phase

- Display update plan (current → latest version)
- Prompt for user confirmation

##### 3. Execution Phase

- Download new versions in parallel
- Clear version pinning in `mod-list.json`
- Old versions remain in MOD directory (Factorio uses latest)

**Restrictions**:
- Cannot update `base` MOD
- Cannot update expansion MODs (e.g., `space-age`)

**Use case**: Keep MODs up to date with latest releases

### MOD::List

List installed MODs with their status.

**Options**:
- `--enabled` - Show only enabled MODs
- `--disabled` - Show only disabled MODs
- `--errors` - Show only MODs with dependency errors
- `--outdated` - Show only MODs with available updates (includes LATEST column)
- `--json` - Output in JSON format

**Output**: Table format by default with NAME, VERSION, STATUS columns. When using `--outdated`, an additional LATEST column shows available update versions.

**Sort order**: base MOD first, then expansion MODs (alphabetically), then other MODs (alphabetically)

**Use case**: Review installed MODs and their status before launching the game

### MOD::Check

Validate dependency integrity of installed MODs.

**Features**:
- Checks if all required dependencies are installed
- Validates version requirements
- Detects incompatibilities (including bidirectional checks)
- Reports missing dependencies and version mismatches

**Use case**: Verify MOD configuration before launching the game

### MOD::Search

Search MODs on Factorio MOD Portal.

**Arguments**:
- `mod_names` - MOD names to search (optional, array)

**Options**:
- `--hide-deprecated` - Hide deprecated MODs (default: true)
- `--page` - Page number (default: 1)
- `--page-size` - Results per page (default: 25, max 500)
- `--sort` - Sort field (name, created_at, updated_at)
- `--sort-order` - Sort order (asc, desc)
- `--version` - Filter by Factorio version (default: installed version)
- `--json` - Output in JSON format

**Output**: Table format by default with NAME, TITLE, CATEGORY, OWNER, LATEST columns

**Use case**: Search for MODs before downloading or installing

### MOD::Show

Show detailed MOD information from Factorio MOD Portal.

**Arguments**:
- `mod_name` - MOD name to show (required)

**Output**: Text format showing:
- Title, summary
- Status (Enabled/Disabled/Not installed)
- Version (latest from portal)
- Author, category, license, Factorio version, downloads count
- Installed version with update indicator (if installed)
- Links (MOD Portal, source URL, homepage)
- Dependencies (required and optional)
- Incompatibilities

**Use case**: View detailed MOD information before installing or to check for updates

### MOD::Sync

Synchronize MOD states from a save file.

**Features**:
- Extracts MOD information from save file
- Downloads missing MODs concurrently
- Enables MODs to match save file state
- Preserves existing MOD files when possible

**Use case**: Set up MOD environment to match a specific save file

### MOD::Edit

Edit MOD details on the portal.

**Editable fields**:
- `title` - MOD title (max 250 characters)
- `summary` - Brief description (max 500 characters)
- `description` - Full description
- `category` - Category (automation, content, balance, etc.)
- `tags` - Tags (array)
- `license` - License name
- `homepage` - Homepage URL (max 256 characters)
- `source_url` - Source code URL (max 256 characters)
- `faq` - FAQ text
- `deprecated` - Mark as deprecated (boolean)

**Authentication**: Requires API key with `ModPortal: Edit Mods` permission

### MOD::Upload

Upload MOD to Factorio MOD Portal.

**Features**:
- Handles both new MOD publication and version updates
- Validates MOD zip file structure
- Supports optional metadata (description, category, license, source URL)

**Options**:
- `--description` - Markdown description
- `--category` - MOD category
- `--license` - License identifier
- `--source_url` - Repository URL

**Authentication**: Requires API key with `ModPortal: Upload Mods` permission

### MOD::Image::List

List all images for a MOD with their IDs and URLs.

**Options**:
- `--json` - Output in JSON format

**Output**: Table format by default showing:
- Image ID (SHA1 hash)
- Full-size image URL
- Thumbnail URL

**Data source**: Retrieved from `GET /mods/{name}/full` API endpoint

**Use case**: Get image IDs needed for the `image edit` command

### MOD::Image::Add

Add an image to a MOD on the portal.

**Response**: Returns image ID (SHA1), URL, and thumbnail URL for uploaded image

**Authentication**: Requires API key with `ModPortal: Edit Mods` permission

### MOD::Image::Edit

Edit MOD image list on the portal.

**Purpose**: Reorder or remove images by specifying image IDs in desired order

**Authentication**: Requires API key with `ModPortal: Edit Mods` permission

### MOD::Settings::Dump

Export MOD settings to JSON format.

**Arguments**:
- `settings_file` - Path to mod-settings.dat file (optional, defaults to runtime path)

**Options**:
- `-o`, `--output` - Output file path (defaults to stdout)

**Output**: JSON format with game version and settings organized by section (startup, runtime-global, runtime-per-user)

**File format**: The binary `mod-settings.dat` file is converted to human-readable JSON with proper indentation.

### MOD::Settings::Restore

Restore MOD settings from JSON format.

**Backup**: Automatically creates a backup with `.bak` extension before overwriting (customizable with `--backup-extension`)

**File format**: Reads JSON file and converts it back to the binary `mod-settings.dat` format used by Factorio.

## Related Documentation

- [Storage Management](storage.md)
- [API/Portal Layer](api-portal.md)
- [Technology Stack](../technology-stack.md)
