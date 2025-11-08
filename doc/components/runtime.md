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

```ruby
class Runtime::Base
  # XDG Base Directory specification
  def xdg_cache_home_dir
    if ENV.key?("XDG_CACHE_HOME")
      Pathname(ENV.fetch("XDG_CACHE_HOME"))
    else
      default_cache_home_dir
    end
  end

  def xdg_config_home_dir
    if ENV.key?("XDG_CONFIG_HOME")
      Pathname(ENV.fetch("XDG_CONFIG_HOME"))
    else
      default_config_home_dir
    end
  end

  def xdg_data_home_dir
    if ENV.key?("XDG_DATA_HOME")
      Pathname(ENV.fetch("XDG_DATA_HOME"))
    else
      default_data_home_dir
    end
  end

  private

  # Platform-specific defaults (override in subclasses)
  # Note: Pathname does not expand '~', so use Dir.home explicitly
  def default_cache_home_dir
    Pathname(Dir.home).join(".cache")  # Linux/macOS/WSL
  end

  def default_config_home_dir
    Pathname(Dir.home).join(".config")  # Linux/macOS/WSL
  end

  def default_data_home_dir
    Pathname(Dir.home).join(".local/share")  # Linux/macOS/WSL
  end
end
```

**Windows-specific defaults**:

```ruby
class Runtime::Windows < Runtime::Base
  private

  def default_cache_home_dir
    Pathname(ENV.fetch("LOCALAPPDATA"))
  end

  def default_config_home_dir
    Pathname(ENV.fetch("APPDATA"))
  end

  def default_data_home_dir
    Pathname(ENV.fetch("LOCALAPPDATA"))
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
