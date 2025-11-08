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

### Design Policy

- Make progress notification functionality injectable (DI)
- Unified interface for download/upload
- Standard implementation: Use ruby-progressbar (Progress::Bar)

### Progress::Base Interface

- `on_start(total_size)` - At transfer start (receives total size)
- `on_progress(current_size)` - On progress update (receives current size)
- `on_complete` - At transfer complete

### Implementation Method

- Manually notify progress during chunk read/write with net/http
- Download: Notify while reading response body with `Net::HTTP#request`
- Upload: Notify while writing request body

## Related Documentation

- [API/Portal Layer](api-portal.md)
- [Cache](storage.md#cache)
- [Technology Stack](../technology-stack.md)
