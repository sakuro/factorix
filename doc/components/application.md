# Application Configuration and DI

Component that manages dependency management and configuration for the entire application.

## Structure

- `extend Dry::Container::Mixin` - Dependency container
- `extend Dry::Configurable` - Configuration management

## Configuration Items

Uses default values compliant with XDG Base Directory specification via Runtime abstraction.

```ruby
setting :cache_dir, default: -> {
  runtime.xdg_cache_home_dir / "factorix"
}
setting :config_dir, default: -> {
  runtime.xdg_config_home_dir / "factorix"
}
setting :log_level, default: :info
setting :http do
  setting :open_timeout, default: 60
  setting :read_timeout, default: 60
end
```

**Benefits**:
- Platform-aware XDG directory handling (Linux/macOS/Windows/WSL)
- Centralized path logic in Runtime classes
- Proper Windows AppData directory support

### XDG Environment Variable Support

| Configuration Item | Runtime Method | Environment Variable | Default (Linux/macOS/WSL) | Default (Windows) |
|-------------------|----------------|---------------------|---------------------------|-------------------|
| cache_dir | `xdg_cache_home_dir` | `XDG_CACHE_HOME` | `~/.cache/factorix` | `%LOCALAPPDATA%\factorix` |
| config_dir | `xdg_config_home_dir` | `XDG_CONFIG_HOME` | `~/.config/factorix` | `%APPDATA%\factorix` |

## Container Registration

- `cache` - Cache instance
- `logger` - Logger instance
- `retry_strategy` - Retry strategy
- `service_credential` - Factorio service credentials
- `api_credential` - Portal API credentials
- Other common services

## Configuration File Loading

### File Path (XDG-compliant)

- `$XDG_CONFIG_HOME/factorix/config.rb` (if environment variable is set)
- `~/.config/factorix/config.rb` (default)

### Configuration File Format (Ruby DSL)

```ruby
Factorix::Application.configure do |config|
  config.cache_dir = "/custom/cache/path"
  config.log_level = :debug
  config.http.open_timeout = 120
end
```

## Dependency Injection

```ruby
Import = Dry::AutoInject(Factorix::Application)

class SomeClass
  include Import["cache", "logger"]
end
```

## Related Documentation

- [Architecture](../architecture.md)
- [Credentials Management](credentials.md)
- [Technology Stack](../technology-stack.md)
