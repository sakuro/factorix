# Storage Management

## Cache

Multi-backend caching for downloaded files, API responses, and MOD metadata.

See [cache.md](cache.md) for detailed documentation on:
- Backend implementations (FileSystem, Redis, S3)
- Configuration and usage
- Architecture and internals

## MODSettings

Manages reading and writing of `mod-settings.dat` file. Uses SerDes module to handle Factorio-specific binary format.

### Configuration Sections

- `startup` - Startup settings (before world generation)
- `runtime-global` - Runtime global settings (common to all players)
- `runtime-per-user` - Runtime per-user settings

### Main Features

- `MODSettings.load` - Load mod-settings.dat file (path defaults to runtime)
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
settings = MODSettings.load
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

- `MODList.load` - Load from mod-list.json (path defaults to runtime)
- `save` - Save to mod-list.json (path defaults to runtime)
- `add(mod, enabled:, version:)` - Add MOD to list
- `remove(mod)` - Remove MOD from list
- `enable(mod)` / `disable(mod)` - Enable/disable MOD
- `enabled?(mod)` - Check MOD enabled state
- `exist?(mod)` - Check if MOD exists in list
- `each` - Iterate over MOD and state pairs
- `each_mod` - Iterate over MODs only

### Special Rules

- `base` MOD is always enabled (cannot be disabled or removed)
- Expansion MODs cannot be removed (can only be disabled)
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

- `MOD::Enable` - Enable MOD
- `MOD::Disable` - Disable MOD

## InstalledMOD

Represents an installed MOD with its metadata (Data.define).

### Overview

- Scans MOD directory to discover installed MODs
- Supports both ZIP and directory forms
- Provides access to MOD metadata (info.json)

### Data Structure

- `mod` - MOD object
- `version` - MOD version (MODVersion)
- `form` - Installation form (`:zip` or `:directory`)
- `path` - Path to MOD file or directory
- `info` - InfoJSON object (parsed info.json)

### Main Features

- `InstalledMOD.all` - Scan and return all installed MODs
- `InstalledMOD.each {|mod| ... }` - Iterate over installed MODs
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
- `MOD::Uninstall` - Removes InstalledMOD entries
- `MOD::Sync` - Uses InstalledMOD.all to check existing MODs
- `MOD::Check` - Uses InstalledMOD.all to validate dependencies

## Related Documentation

- [CLI Commands](cli.md)
- [Architecture](../architecture.md)
