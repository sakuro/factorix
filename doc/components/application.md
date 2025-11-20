# Application Configuration and DI

Component that manages dependency management and configuration for the entire application.

## Structure

- `extend Dry::Container::Mixin` - Dependency container
- `extend Dry::Configurable` - Configuration management

## Configuration Items

```ruby
setting :log_level, default: :info

setting :credential do
  setting :source, default: :player_data # :player_data or :env
end

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
end
```

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
  include Import[:cache, :logger]
end
```

## Related Documentation

- [Architecture](../architecture.md)
- [Credentials Management](credentials.md)
- [Technology Stack](../technology-stack.md)
