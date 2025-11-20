# Storage Management

## Cache

Caches downloaded files and API call results.

### Initial Implementation

Filesystem-based cache (Cache::FileSystem).

### Design Policy

- Define interface to allow backend replacement
- Cache expiration management
- API cache and download cache can be created independently
- They are not shared (separate cache instances)

### Concurrent Access Countermeasures (reference existing implementation)

- Use file locking (flock)
- Acquire exclusive lock with `with_lock` method
- Cleanup old lock files (more than 1 hour old)
- Two-level directory structure (first 2 characters of SHA1 hash as prefix)
- Keys generated as SHA1 hash

## MODSettings

Manages reading and writing of `mod-settings.dat` file. Uses SerDes module to handle Factorio-specific binary format.

### Configuration Sections

- `startup` - Startup settings (before world generation)
- `runtime-global` - Runtime global settings (common to all players)
- `runtime-per-user` - Runtime per-user settings

### Main Features

- `MODSettings.new(path)` - Load mod-settings.dat file
- `[section_name]` - Access section
- `each_section` - Iterate over all sections

### Internal Classes

#### MODSettings::Section

Represents a configuration section.

**Methods**:
- `[key]` / `[key]=value` - Access configuration values
- `each` - Iterate over configurations in section
- `empty?` - Check if section is empty

### File Format (Binary)

1. GameVersion (fixed 8 bytes: u16×4)
2. Bool (1 byte) - Skip
3. Property Tree (section structure)
   - Section name → configuration group
   - Configuration: `key => {"value" => actual_value}`

### Usage Example

```ruby
settings = MODSettings.new(Pathname("mod-settings.dat"))
startup = settings["startup"]
startup.each do |key, value|
  puts "#{key}: #{value}"
end
```

### Command Integration

- `MOD::Settings::Dump` - Convert mod-settings.dat → JSON
- `MOD::Settings::Restore` - Convert JSON → mod-settings.dat

## MODList

Manages reading and writing of `mod-list.json` file.

### Overview

- Manage list of installed MODs and their enabled/disabled state
- Use standard library `json` (SerDes not required)

### Data Structure

Manages pairs of MOD and MODState.

#### MOD (Data.define)

- `name` - MOD name

#### MODState (Data.define)

- `enabled` - Enabled/disabled flag
- `version` - Version string (optional)

### Main Features

- `MODList.load(from:)` - Load from mod-list.json
- `save(to:)` - Save to mod-list.json
- `add(mod, enabled:, version:)` - Add MOD to list
- `remove(mod)` - Remove MOD from list
- `enable(mod)` / `disable(mod)` - Enable/disable MOD
- `enabled?(mod)` - Check MOD enabled state
- `exist?(mod)` - Check if MOD exists in list
- `each` - Iterate over MOD and state pairs
- `each_mod` - Iterate over MODs only

### Special Rules

- `base` MOD is always enabled (cannot be disabled or removed)
- Version information is optional (included in JSON only if exists)

### File Format (JSON)

```json
{
  "mods": [
    {"name": "base", "enabled": true},
    {"name": "some-mod", "enabled": true, "version": "1.0.0"}
  ]
}
```

### Usage Example

```ruby
mod_list = MODList.load
mod_list.add(MOD[name: "new-mod"], enabled: true, version: "1.0.0")
mod_list.disable(MOD[name: "some-mod"])
mod_list.save
```

### Command Integration

- `MOD::List` - Display MOD list
- `MOD::Enable` - Enable MOD
- `MOD::Disable` - Disable MOD

## InstalledMOD

Represents an installed MOD with its metadata (Data.define).

### Overview

- Scans MOD directory to discover installed MODs
- Supports both ZIP and directory forms
- Provides access to MOD metadata (info.json)

### Data Structure

- `name` - MOD name
- `version` - MOD version
- `path` - Path to MOD file or directory
- `form` - Installation form (`:zip` or `:directory`)
- `metadata` - Hash of info.json contents

### Main Features

- `InstalledMOD.all(mod_dir)` - Scan and return all installed MODs
- `InstalledMOD.each(mod_dir) {|mod| ... }` - Iterate over installed MODs
- `InstalledMOD.from_zip(path)` - Create from ZIP file
- `InstalledMOD.from_directory(path)` - Create from directory
- `base?` - Check if base MOD
- `expansion?` - Check if expansion

### InstalledMOD::Scanner

Internal class that scans MOD directory for installed MODs.

**Features**:
- Supports both ZIP and directory forms
- Validates info.json presence
- Handles missing or invalid MODs gracefully
- Prefers ZIP form over directory form (higher priority)

### Command Integration

- `MOD::Install` - Creates InstalledMOD entries
- `MOD::Sync` - Uses InstalledMOD.all to check existing MODs
- `MOD::Check` - Uses InstalledMOD.all to validate dependencies

## Related Documentation

- [CLI Commands](cli.md)
- [Technology Stack](../technology-stack.md)
