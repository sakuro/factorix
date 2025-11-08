# Data Serialization (SerDes)

Module for reading and writing Factorio-specific binary format (Property Tree format).

- **Main use**: Reading and writing `mod-settings.dat`
- **Reference**: https://wiki.factorio.com/Property_tree

## Consumers

- `MODSettings` - Load mod-settings.dat
- `CLI::Commands::MOD::Settings::Dump` - Convert mod-settings.dat → TOML
- `CLI::Commands::MOD::Settings::Load` - Convert TOML → mod-settings.dat

## Internal Classes

### Deserializer

Handles deserialization from binary.

**Main methods**:
- `read_game_version` - Read GameVersion object
- `read_mod_version` - Read MODVersion object
- `read_property_tree` - Read Property Tree structure
- `read_u8`, `read_u16`, `read_u32` - Read integer types
- `read_optim_u16`, `read_optim_u32` - Read space-optimized integers
- `read_bool`, `read_str`, `read_double` - Read basic types
- `read_dictionary`, `read_list` - Read structured data

### Serializer

Handles serialization to binary.

**Main methods**:
- `write_game_version`, `write_mod_version` - Write version information
- `write_property_tree` - Write Property Tree structure
- `write_u8`, `write_u16`, `write_u32` - Write integer types
- `write_optim_u16`, `write_optim_u32` - Write space-optimized integers
- `write_bool`, `write_str`, `write_double` - Write basic types
- `write_dictionary`, `write_list` - Write structured data

### GameVersion

Version for game/file format (formerly Version64).

**Specification**:
- 4 components: major, minor, patch, build
- Each component: u16 (fixed 8 bytes)
- String format: "X.Y.Z-B"
- Use: mod-settings.dat header, etc.

### MODVersion

Version for MODs (formerly Version24).

**Specification**:
- 3 components: major, minor, patch
- Each component: optimized_u16 (variable 3-6 bytes)
- String format: "X.Y.Z"
- Use: MOD information in save data (future support planned)

## Property Tree Supported Types

- **Type 0**: None (nil)
- **Type 1**: Bool
- **Type 2**: Number (double)
- **Type 3**: String
- **Type 4**: List (array)
- **Type 5**: Dictionary (hash) / RGBA color information
- **Type 6**: Signed integer (64bit)
- **Type 7**: Unsigned integer (64bit)

## RGBA Color Information Special Handling

- If keys in Dictionary are `["a", "b", "g", "r"]`, treat as RGBA color information
- Internal representation: Convert to string in `"rgba:RRGGBBAA"` format

## Related Documentation

- [MODSettings](storage.md#modsettings)
- [CLI Commands](cli.md)
