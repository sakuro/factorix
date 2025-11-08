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

- `mods_dir` - Get MOD directory path
- `player_data_path` - Get player-data.json path
- `xdg_cache_home_dir` - Get XDG cache home directory (platform-aware)
- `xdg_config_home_dir` - Get XDG config home directory (platform-aware)
- `xdg_data_home_dir` - Get XDG data home directory (platform-aware)
- Other platform-specific path information

### XDG Base Directory Support

Runtime classes abstract XDG Base Directory specification across platforms:

```ruby
class Runtime::Base
  # XDG Base Directory specification
  def xdg_cache_home_dir
    Pathname(ENV.fetch("XDG_CACHE_HOME", default_cache_home_dir)).expand_path
  end

  def xdg_config_home_dir
    Pathname(ENV.fetch("XDG_CONFIG_HOME", default_config_home_dir)).expand_path
  end

  def xdg_data_home_dir
    Pathname(ENV.fetch("XDG_DATA_HOME", default_data_home_dir)).expand_path
  end

  private

  # Platform-specific defaults (override in subclasses)
  def default_cache_home_dir
    "~/.cache"  # Linux/macOS/WSL
  end

  def default_config_home_dir
    "~/.config"  # Linux/macOS/WSL
  end

  def default_data_home_dir
    "~/.local/share"  # Linux/macOS/WSL
  end
end
```

**Windows-specific defaults**:

```ruby
class Runtime::Windows < Runtime::Base
  private

  def default_cache_home_dir
    ENV.fetch("LOCALAPPDATA", "~/AppData/Local")
  end

  def default_config_home_dir
    ENV.fetch("APPDATA", "~/AppData/Roaming")
  end

  def default_data_home_dir
    ENV.fetch("LOCALAPPDATA", "~/AppData/Local")
  end
end
```

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
