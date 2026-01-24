# Storage Management

## Cache

Caches downloaded files, API call results, and MOD metadata (info.json from ZIP files).

### Initial Implementation

Filesystem-based cache (Cache::FileSystem).

### Design Policy

- Define interface to allow backend replacement
- Cache expiration management
- Caches are created independently (API, download, info.json)

### Backend Initialization

All cache backends (`FileSystem`, `Redis`, and `S3`) receive a `cache_type` parameter (`:download`, `:api`, or `:info_json`) and auto-compute their storage locations:

- **FileSystem**: Cache directory is `{factorix_cache_dir}/{cache_type}`
- **Redis**: Namespace prefix is `factorix-cache:{cache_type}:`
- **S3**: Object prefix is `cache/{cache_type}/`

This ensures consistent naming across backends and simplifies configuration.

### Compression Support

Optional zlib compression for cached data:

- `compression_threshold: nil` - No compression (default)
- `compression_threshold: N` - Compress if data >= N bytes (0 means always compress)

Detection on read uses zlib magic byte (`0x78`) to handle mixed compressed/uncompressed entries within the same cache.

**Default Configuration**:
- API cache: `compression_threshold: 0` (JSON responses compress well)
- Download cache: `compression_threshold: nil` (ZIP files are already compressed)
- Info.json cache: `compression_threshold: 0` (JSON data compresses well)

### Directory Structure

- Keys generated as SHA1 hash of URL/identifier
- Two-level directory structure (first 2 characters of SHA1 hash as prefix)
  - Avoids filesystem performance degradation from too many files in one directory

### Concurrent Access Countermeasures

- Use file locking (flock)
- Acquire exclusive lock with `with_lock` method
- Cleanup old lock files (more than 1 hour old)

### Redis Backend

Optional Redis-based cache (Cache::Redis) for distributed environments.

**URL Resolution Order**:
1. Explicit `url` setting in configuration
2. `REDIS_URL` environment variable
3. Default: `localhost:6379` (Redis gem default)

**Configuration Example**:
```ruby
Factorix.configure do |config|
  config.cache.api.backend = :redis
  config.cache.api.redis.url = "redis://redis-server:6379/0"
  config.cache.api.redis.lock_timeout = 30
end
```

**Key Structure**:
- Data: `factorix-cache:{cache_type}:{key}`
- Metadata: `factorix-cache:{cache_type}:meta:{key}`
- Lock: `factorix-cache:{cache_type}:lock:{key}`

**Distributed Locking**:
- Atomic acquire with `SET NX EX`
- Atomic release with Lua script (ownership check)
- Lock timeout configurable (default: 30 seconds)

### S3 Backend

Optional S3-based cache (Cache::S3) for cloud-native deployments.

**Configuration Example**:
```ruby
Factorix.configure do |config|
  config.cache.download.backend = :s3
  config.cache.download.s3.bucket = "factorix-cache"
  config.cache.download.s3.region = "ap-northeast-1"
  config.cache.download.s3.lock_timeout = 30
end
```

**Region Resolution Order**:
1. Explicit `region` setting in configuration
2. `AWS_REGION` environment variable
3. AWS SDK default behavior

**Key Structure**:
- Data: `cache/{cache_type}/{key}`
- Lock: `cache/{cache_type}/{key}.lock`

**TTL Management**:
- TTL stored in S3 object custom metadata (`expires-at`)
- Age calculated from S3's native `Last-Modified` header

**Distributed Locking**:
- Atomic acquire with conditional PUT (`if_none_match: "*"`)
- Lock value includes UUID and expiration timestamp
- Stale locks auto-cleaned on acquisition attempt
- Lock timeout configurable (default: 30 seconds)

**Required IAM Permissions**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:HeadObject"
    ],
    "Resource": [
      "arn:aws:s3:::factorix-cache",
      "arn:aws:s3:::factorix-cache/*"
    ]
  }]
}
```

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
- [Technology Stack](../technology-stack.md)
