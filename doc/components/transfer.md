# File Transfer Components

## Transfer::RetryStrategy

Wrapper class for retriable gem. Centrally manages retry logic for network operations.

### Default Settings

- **tries**: 3 (3 attempts including initial try)
- **exponential backoff**: 1s → 2s → 4s...
- **randomization**: ±25% (distribute server load)
- **target exceptions**:
  - `Errno::ETIMEDOUT`, `Errno::ECONNRESET`, `Errno::ECONNREFUSED`
  - `Net::OpenTimeout`, `Net::ReadTimeout`
  - `SocketError`, `OpenSSL::SSL::SSLError`, `EOFError`

### Usage Example

```ruby
retry_strategy = Transfer::RetryStrategy.new
retry_strategy.with_retry do
  # Network operation
end
```

### Customization

```ruby
Transfer::RetryStrategy.new(
  tries: 5,
  base_interval: 2.0,
  on_retry: ->(exception, try, elapsed_time, next_interval) {
    logger.warn "Retry #{try}: #{exception.message}"
  }
)
```

### dry-container Registration

```ruby
Application.register "retry_strategy" { Transfer::RetryStrategy.new }
```

### Consumers

- `Transfer::HTTP` - Retry for HTTP communication

## Transfer::HTTP

net/http wrapper class. Used for both download and upload.

### Design Policy

- **Use net/http** (do not use open-uri)
- Reason: To achieve consistent event management for both download and upload
- Resume functionality support
- Progress notification functionality

## Transfer::Downloader

Class for downloading files from the portal.

### Basic Flow

1. Check cache
2. If cache doesn't exist, perform actual download
3. Copy cache file to download path

### HTTP Implementation

- **Use net/http** (do not use open-uri)
- Reason: To achieve consistent event management for both download and upload

## Transfer::Uploader

Class for uploading files to the portal.

### HTTP Implementation

- **Use net/http**
- Build multipart/form-data format requests

## Common: Progress Notification Functionality

### Design Policy (Updated 2025-11-09)

- Use **dry-events** for event-driven progress notification
- Transfer layer publishes events, subscribers listen
- Standard implementation: Progress::Bar as event listener
- Extensible: Can add logging, metrics, APM subscribers

### Event-Based Architecture

Transfer layer includes `Dry::Events::Publisher[:transfer]` and publishes events:

**Download events:**
- `download.started` - payload: `{ total_size: Integer }`
- `download.progress` - payload: `{ current_size: Integer, total_size: Integer }`
- `download.completed` - payload: `{ total_size: Integer }`

**Upload events:**
- `upload.started` - payload: `{ total_size: Integer }`
- `upload.progress` - payload: `{ current_size: Integer, total_size: Integer }`
- `upload.completed` - payload: `{ total_size: Integer }`

### Progress::Bar as Event Listener

Implements event handler methods following dry-events convention:

```ruby
class Progress::Bar
  def on_download_started(event)
    @bar.total = event[:total_size]
  end

  def on_download_progress(event)
    @bar.progress = event[:current_size]
  end

  def on_download_completed(event)
    @bar.finish
  end

  # Similar methods for upload events
end
```

### Usage

```ruby
# Subscribe progress bar to transfer events
http = Transfer::HTTP.new
http.subscribe(Progress::Bar.new)
http.download(url, output)

# Multiple subscribers possible
http.subscribe(Progress::Bar.new)
http.subscribe(MyLogger.new)
http.subscribe(MyMetrics.new)
```

### Implementation Method

- Manually publish events during chunk read/write with net/http
- Download: Publish while reading response body with `Net::HTTP#request`
- Upload: Publish while writing request body

## Related Documentation

- [API/Portal Layer](api-portal.md)
- [Cache](storage.md#cache)
- [Technology Stack](../technology-stack.md)
