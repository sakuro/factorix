# Application Configuration and DI

Component that manages dependency management and configuration for the entire application.

## Structure

- `extend Dry::Container::Mixin` - Dependency container
- `extend Dry::Configurable` - Configuration management

## Configuration Items

```ruby
setting :log_level, default: :info

setting :runtime do
  setting :executable_path, constructor: ->(v) { v ? Pathname(v) : nil }
  setting :user_dir, constructor: ->(v) { v ? Pathname(v) : nil }
  setting :data_dir, constructor: ->(v) { v ? Pathname(v) : nil }
end

setting :http do
  setting :connect_timeout, default: 5
  setting :read_timeout, default: 30
  setting :write_timeout, default: 30
end

setting :cache do
  setting :download do
    setting :dir, constructor: ->(value) { Pathname(value) }
    setting :ttl, default: nil
    setting :max_file_size, default: nil
  end

  setting :api do
    setting :dir, constructor: ->(value) { Pathname(value) }
    setting :ttl, default: 3600
    setting :max_file_size, default: 10 * 1024 * 1024
  end

  setting :info_json do
    setting :dir, constructor: ->(value) { Pathname(value) }
    setting :ttl, default: nil  # nil for unlimited (info.json is immutable within a MOD ZIP)
    setting :max_file_size, default: nil
  end
end
```

## Container Registration

- `logger` - Logger instance
- `retry_strategy` - Retry strategy
- `service_credential` - Factorio service credentials
- `api_credential` - Portal API credentials
- Other common services

## Configuration File Loading

### Loading Priority

Configuration file is resolved in the following order:

1. `--config-path` CLI option (if specified)
2. `FACTORIX_CONFIG` environment variable (if set)
3. Default path (XDG-compliant):
   - `$XDG_CONFIG_HOME/factorix/config.rb` (if `XDG_CONFIG_HOME` is set)
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
  include Import[:logger, cache: :api_cache]
end
```

## Related Documentation

- [Architecture](../architecture.md)
- [Credentials Management](credentials.md)
- [Technology Stack](../technology-stack.md)
