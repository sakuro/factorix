# CLI Command Details

## Basic Structure

- Register commands using dry-cli `Registry`
- Commands are placed under `CLI::Commands` module
- **Output Guidelines**: Commands use `say()` for human-readable messages (respects `--quiet`) and `puts()` for structured data output (always outputs). See [CLI Output Guidelines](../../DEVELOPMENT.md#cli-output-guidelines) for detailed conventions.

## Command List

### Path

Display all Factorio and Factorix paths.

```bash
factorix path
```

**Output**: JSON format with path types as keys (snake_case) and path values as values

**Included paths**:
- `executable_path` - Factorio executable file
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

### Launch

Launch the game.

```bash
factorix launch
factorix launch -- --verbose --benchmark save.zip
```

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

```bash
factorix mod download some-mod              # Latest version
factorix mod download some-mod@1.2.0        # Specify version
factorix mod download some-mod --directory=/tmp/mods
factorix mod download some-mod --recursive  # Include dependencies
```

**Behavior**:
- Download to any location (specify with `--directory` or `-d`, defaults to current directory)
- Dependencies are not included by default (use `--recursive` or `-r` to include required dependencies)
- Don't modify `mod-list.json`
- Use cache

**Purpose**: When only retrieving MOD files is the goal

#### Install Command

```bash
factorix mod install some-mod               # Latest version
factorix mod install some-mod@1.2.0         # Specify version
```

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
  - Incompatible with existing mod: conflicting-mod@2.0.0
  - Required dependency base >= 2.0.0 not satisfied (current: 1.1.0)
```

#### Uninstall Command

```bash
factorix mod uninstall some-mod
```

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

### MOD::List

List installed MODs with their status.

```bash
factorix mod list
factorix mod list --enabled
factorix mod list --disabled
factorix mod list --outdated
factorix mod list --json
```

**Options**:
- `--enabled` - Show only enabled MODs
- `--disabled` - Show only disabled MODs
- `--errors` - Show only MODs with dependency errors
- `--outdated` - Show only MODs with available updates (includes LATEST column)
- `--json` - Output in JSON format

**Output**: Table format by default with NAME, VERSION, STATUS columns. When using `--outdated`, an additional LATEST column shows available update versions.

**Sort order**: base MOD first, then expansion MODs (alphabetically), then other MODs (alphabetically)

**Use case**: Review installed MODs and their status before launching the game

### MOD::Publish

Publish and upload MODs.

- First time: Use MOD publication API
- Subsequent: Use MOD upload API

### MOD::Check

Validate dependency integrity of installed MODs.

```bash
factorix mod check
```

**Features**:
- Checks if all required dependencies are installed
- Validates version requirements
- Detects incompatibilities (including bidirectional checks)
- Reports missing dependencies and version mismatches

**Use case**: Verify MOD configuration before launching the game

### MOD::Sync

Synchronize MOD states from a save file.

```bash
factorix mod sync save-file.zip
```

**Features**:
- Extracts MOD information from save file
- Downloads missing MODs concurrently
- Enables MODs to match save file state
- Preserves existing MOD files when possible

**Use case**: Set up MOD environment to match a specific save file

### MOD::Edit

Edit MOD details on the portal.

```bash
factorix mod edit some-mod --title "New Title"
factorix mod edit some-mod --summary "Brief description"
factorix mod edit some-mod --description "Full description"
factorix mod edit some-mod --category automation
factorix mod edit some-mod --license MIT
```

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

### MOD::Image::List

List all images for a MOD with their IDs and URLs.

```bash
factorix mod image list some-mod
```

**Output**: Displays image information including:
- Image ID (SHA1 hash)
- Full-size image URL
- Thumbnail URL

**Data source**: Retrieved from `GET /mods/{name}/full` API endpoint

**Use case**: Get image IDs needed for the `image edit` command

### MOD::Image::Add

Add an image to a MOD on the portal.

```bash
factorix mod image add some-mod screenshot.png
```

**Response**: Returns image ID (SHA1), URL, and thumbnail URL for uploaded image

**Authentication**: Requires API key with `ModPortal: Edit Mods` permission

### MOD::Image::Edit

Edit MOD image list on the portal.

```bash
factorix mod image edit some-mod image-id-1 image-id-2 image-id-3
```

**Purpose**: Reorder or remove images by specifying image IDs in desired order

**Authentication**: Requires API key with `ModPortal: Edit Mods` permission

### MOD::Settings::Dump

Export mod settings to JSON format.

```bash
# Dump to stdout
factorix mod settings dump

# Dump to file
factorix mod settings dump -o settings.json

# Dump from specific mod-settings.dat file
factorix mod settings dump /path/to/mod-settings.dat -o settings.json
```

**Output**: JSON format with game version and settings organized by section (startup, runtime-global, runtime-per-user)

**File format**: The binary `mod-settings.dat` file is converted to human-readable JSON with proper indentation.

### MOD::Settings::Restore

Restore mod settings from JSON format.

```bash
# Restore from file
factorix mod settings restore -i settings.json

# Restore from stdin
cat settings.json | factorix mod settings restore

# Restore to specific location
factorix mod settings restore -i settings.json /path/to/mod-settings.dat
```

**Backup**: Automatically creates a backup with `.bak` extension before overwriting (customizable with `--backup-extension`)

**File format**: Reads JSON file and converts it back to the binary `mod-settings.dat` format used by Factorio.

## Related Documentation

- [MOD Dependency Management](dependencies.md)
- [Storage Management](storage.md)
- [API/Portal Layer](api-portal.md)
- [Technology Stack](../technology-stack.md)
