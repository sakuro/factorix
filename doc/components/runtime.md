# Runtime Environment Abstraction

Component that abstracts various runtime environments.

## Supported Platforms

- **macOS** - Runtime::MacOS
- **Linux** - Runtime::Linux
- **Windows** - Runtime::Windows
- **WSL** - Runtime::WSL

## Design Policy

- Define common interface (Runtime::Base)
- Platform-specific implementations provided by each subclass
- Implement file path and directory retrieval methods for each platform

## Main Features

Each Runtime class provides methods such as:

- `user_dir` - Get Factorio user directory path (platform-specific, abstract)
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
Factorix::Application.configure do |config|
  config.runtime.executable_path = "/path/to/factorio"
  config.runtime.user_dir = "/path/to/factorio/user/dir"
  config.runtime.data_dir = "/path/to/factorio/data"
end
```

**Resolution order**:
1. User-configured value (via `config.runtime.*`)
2. Platform-specific auto-detection
3. Raises `ConfigurationError` if neither is available

All path resolution decisions are logged at DEBUG level.

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
