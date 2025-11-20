# CLI Command Details

## Basic Structure

- Register commands using dry-cli `Registry`
- Commands are placed under `CLI::Commands` module

## Command List

### Path

Display Factorio and Factorix paths.

```bash
# Display all paths
factorix path

# Display specific paths
factorix path mod-dir user-dir

# Underscore notation is also accepted (automatically normalized to hyphens)
factorix path mod_dir user_dir
```

**Output**: JSON format with path types as keys and path values as values

**Available path types**:
- `executable-path` - Factorio executable file
- `user-dir` - Factorio user directory
- `mod-dir` - MODs directory
- `save-dir` - Saves directory
- `script-output-dir` - Script output directory
- `mod-list-path` - mod-list.json file
- `mod-settings-path` - mod-settings.dat file
- `player-data-path` - player-data.json file
- `lock-path` - Lock file (indicates if game is running)
- `factorix-cache-dir` - Factorix cache directory
- `factorix-config-path` - Factorix configuration file
- `factorix-log-path` - Factorix log file

**Error handling**: When unknown path types are specified, displays available path types in bulleted list format:
```
Unknown path types:
- invalid-type

Available path types:
- executable-path
- factorix-cache-dir
- factorix-config-path
...
```

### Launch

Launch the game.

**Features**:
- Pass options to Factorio
- Prevent multiple simultaneous launches
- Automatically wait for termination for certain commands

### MOD::List

Display MOD list (name, version, state, etc.).

### MOD::Enable

Enable the specified MOD.

### MOD::Disable

Disable the specified MOD.

### MOD::Download vs MOD::Install

#### Download Command

```bash
factorix mod download some-mod              # Latest version
factorix mod download some-mod@1.2.0        # Specify version
factorix mod download some-mod --output=/tmp/mods
```

**Behavior**:
- Download to any location (specify with `--output`, defaults to current directory)
- Don't consider dependencies
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
Error: Cannot uninstall base
  - Required by: some-mod@1.2.0, another-mod@3.0.0
  - Uninstall these mods first, or disable them
```

**Design Policy**:
- **Detect errors before destructive operations**: Complete all validation before downloading or enabling
- **Don't implement force option**: YAGNI principle (implement when needed)
- **Version specification support**: `mod-name@version` format, latest version if not specified

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

### MOD::Image::List (Unimplemented)

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

### MOD::Image::Add (Unimplemented)

Add images to a MOD on the portal.

```bash
factorix mod image add some-mod screenshot1.png
factorix mod image add some-mod screenshot2.png screenshot3.png
```

**Response**: Returns image IDs (SHA1), URLs, and thumbnail URLs for uploaded images

**Authentication**: Requires API key with `ModPortal: Edit Mods` permission

### MOD::Image::Edit (Unimplemented)

Edit MOD image order on the portal.

```bash
factorix mod image edit some-mod <image-id-1>,<image-id-2>,<image-id-3>
```

**Purpose**: Reorder images by specifying comma-separated image IDs in desired order

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

## Output Colorization

**Use TIntMe gem** to make terminal output more readable.

### Basic Policy

- Define styles in advance (performance optimization)
- Determine which parts to colorize in the future

### Usage Example

```ruby
# Style definition (pre-defined as constants)
ERROR_STYLE = TIntMe[:red, :bold]
SUCCESS_STYLE = TIntMe[:green]
INFO_STYLE = TIntMe[:blue]
WARNING_STYLE = TIntMe[:yellow]

# Usage
puts ERROR_STYLE["Error: MOD not found"]
puts SUCCESS_STYLE["Successfully installed some-mod"]
```

### Style Composition

```ruby
BASE_STYLE = TIntMe[foreground: :blue]
EMPHASIS_STYLE = TIntMe[bold: true]
COMBINED_STYLE = BASE_STYLE >> EMPHASIS_STYLE
```

### Colorization Candidates (to be determined)

- Error messages (red)
- Success messages (green)
- Warning messages (yellow)
- Info messages (blue)
- MOD names (emphasis)
- Version numbers (emphasis)
- Progress display

## Related Documentation

- [MOD Dependency Management](dependencies.md)
- [Storage Management](storage.md)
- [API/Portal Layer](api-portal.md)
- [Technology Stack](../technology-stack.md)
