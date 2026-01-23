# Container Configuration and DI

Component that manages dependency injection and configuration for the library.

## Structure

- `extend Dry::Core::Container::Mixin` - Dependency container
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
    setting :backend, default: :file_system
    setting :ttl, default: nil
    setting :file_system do
      setting :dir, constructor: ->(v) { v ? Pathname(v) : nil }
      setting :max_file_size, default: nil
      setting :compression_threshold, default: nil
    end
  end

  setting :api do
    setting :backend, default: :file_system
    setting :ttl, default: 3600
    setting :file_system do
      setting :dir, constructor: ->(v) { v ? Pathname(v) : nil }
      setting :max_file_size, default: 10 * 1024 * 1024
      setting :compression_threshold, default: 0
    end
  end

  setting :info_json do
    setting :backend, default: :file_system
    setting :ttl, default: nil
    setting :file_system do
      setting :dir, constructor: ->(v) { v ? Pathname(v) : nil }
      setting :max_file_size, default: nil
      setting :compression_threshold, default: 0
    end
  end
end
```

## Container Registration

- `logger` - Logger instance
- `retry_strategy` - Retry strategy
- `service_credential` - Factorio service credentials
- `api_credential` - Portal API credentials
- `download_cache` - Cache for MOD files
- `api_cache` - Cache for API responses
- `info_json_cache` - Cache for MOD metadata
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
Factorix.configure do |config|
  config.cache_dir = "/custom/cache/path"
  config.log_level = :debug
  config.http.open_timeout = 120
end
```

## Dependency Injection

```ruby
Import = Dry::AutoInject(Factorix::Container)

class SomeClass
  include Import[:logger, cache: :api_cache]
end
```

## Related Documentation

- [Architecture](../architecture.md)
- [Cache System](cache.md)
- [Credentials Management](credentials.md)
- [Technology Stack](../technology-stack.md)
