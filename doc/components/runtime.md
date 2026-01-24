# Runtime Environment Abstraction

Component that abstracts various runtime environments.

## Supported Platforms

All platforms provide auto-detection for Steam installations by default.

| Platform | Class | Default Installation |
|----------|-------|---------------------|
| macOS | Runtime::MacOS | Steam (`~/Library/Application Support/Steam/...`) |
| Linux | Runtime::Linux | Steam (`~/.steam/steam/steamapps/common/Factorio/...`) |
| Windows | Runtime::Windows | Steam (`C:\Program Files (x86)\Steam\...`) |
| WSL | Runtime::WSL | Windows Steam via `/mnt/c/...` |

For non-Steam installations (standalone, Flatpak, Snap, etc.), configure paths via the configuration file.

## Main Features

Each Runtime class provides methods such as:

- `executable_path` - Get Factorio executable path (platform-specific, abstract)
- `user_dir` - Get Factorio user directory path (platform-specific, abstract)
- `data_dir` - Get Factorio data directory path (platform-specific, abstract)
- `mods_dir` - Get MOD directory path (derived from user_dir)
- `player_data_path` - Get player-data.json path (derived from user_dir)
- `xdg_cache_home_dir` - Get XDG cache home directory (platform-aware)
- `xdg_config_home_dir` - Get XDG config home directory (platform-aware)
- `xdg_data_home_dir` - Get XDG data home directory (platform-aware)
- Other platform-specific path information

### Directory Derivation

Most paths are derived from `user_dir`:

```ruby
class Runtime::Base
  # Abstract method - must be implemented by subclasses
  def user_dir
    raise NotImplementedError
  end

  # Derived paths (implemented in base class)
  def mods_dir
    user_dir + "mods"
  end

  def player_data_path
    user_dir + "player-data.json"
  end
end
```

### XDG Base Directory Support

Runtime classes abstract XDG Base Directory specification across platforms:

- `xdg_cache_home_dir` - Cache directory (respects `XDG_CACHE_HOME`)
- `xdg_config_home_dir` - Configuration directory (respects `XDG_CONFIG_HOME`)
- `xdg_data_home_dir` - Data directory (respects `XDG_DATA_HOME`)

Each platform (Linux, macOS, Windows, WSL) provides appropriate default values when environment variables are not set.

### User Configuration Override

The `UserConfigurable` module is prepended to `Runtime::Base` and all its subclasses to allow users to override auto-detected paths via configuration file.

Users can explicitly configure paths in `~/.config/factorix/config.rb` (or `$XDG_CONFIG_HOME/factorix/config.rb`):

```ruby
Factorix.configure do |config|
  config.runtime.executable_path = "/path/to/factorio"
  config.runtime.user_dir = "/path/to/factorio/user/dir"
  config.runtime.data_dir = "/path/to/factorio/data"
end
```

**Resolution order**:
1. User-configured value (via `config.runtime.*`)
2. Platform-specific auto-detection (Steam installation paths)

## File Structure

```
runtime/
├── base.rb           # Abstract base class
├── linux.rb          # Linux implementation
├── mac_os.rb         # macOS implementation
├── windows.rb        # Windows implementation
└── wsl.rb            # WSL implementation
```

## Zeitwerk Configuration

```ruby
loader.inflector.inflect(
  "mac_os" => "MacOS",
  "wsl" => "WSL"
)
```

## Related Documentation

- [Architecture](../architecture.md)
- [Credentials Management](credentials.md)
