# Progress Notification Design Comparison

## Overview

This document compares two architectural approaches for implementing progress notification in the Transfer layer.

## Approach 1: Progress::Base Interface (Current Plan)

### Architecture

```ruby
# Progress interface
class Progress::Base
  def on_start(total_size)
  def on_progress(current_size)
  def on_complete
end

# Usage in Transfer::HTTP
class Transfer::HTTP
  def initialize(progress: nil)
    @progress = progress
  end

  def download(url, output)
    @progress&.on_start(total_size)
    # ... download chunks ...
    @progress&.on_progress(current_size)
    # ... complete ...
    @progress&.on_complete
  end
end

# Inject via DI
http = Transfer::HTTP.new(progress: Progress::Bar.new)
```

### Pros

- **Simple**: Direct method calls, easy to understand
- **Focused**: Specialized for progress tracking only
- **DI-friendly**: Easy to inject different implementations
- **Testable**: Simple to mock in tests
- **Minimal dependencies**: No additional gems required

### Cons

- **Single handler**: Only one progress handler at a time
- **Not event-driven**: Direct coupling between Transfer and Progress
- **Limited extensibility**: Hard to add logging, metrics, etc.
- **No timing info**: Must manually track transfer duration

## Approach 2: dry-events/dry-monitor

### Architecture

```ruby
# Transfer layer publishes events
class Transfer::HTTP
  include Dry::Events::Publisher[:transfer]

  register_event('download.started')
  register_event('download.progress')
  register_event('download.completed')
  register_event('upload.started')
  register_event('upload.progress')
  register_event('upload.completed')

  def download(url, output)
    publish('download.started', url: url, total_size: total_size)
    # ... download chunks ...
    publish('download.progress', current_size: current_size, total_size: total_size)
    # ... complete ...
    publish('download.completed', url: url, total_size: total_size, duration: duration)
  end
end

# Progress bar as event subscriber
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
end

# Subscribe via Application container
Application[:transfer_http].subscribe(Progress::Bar.new)

# Or use dry-monitor for instrumentation
notifications = Dry::Monitor::Notifications.new(:factorix)
notifications.instrument('download', url: url) do
  # download logic
end
```

### Pros

- **Multiple subscribers**: Progress bar, logger, metrics collector simultaneously
- **Event-driven**: Loose coupling, publisher doesn't know about subscribers
- **Extensible**: Easy to add new subscribers (logging, APM, metrics)
- **Instrumentation**: Built-in timing and metadata via dry-monitor
- **dry-rb integration**: Consistent with Application (dry-container, dry-configurable)
- **Testable**: Can verify events are published without needing subscribers

### Cons

- **More complex**: Event publishing/subscription adds indirection
- **Additional dependencies**: Requires dry-events (~> 1.1) and optionally dry-monitor (~> 1.0)
- **Learning curve**: Developers need to understand event system
- **Overhead**: Slight performance cost for event dispatching

## Approach 3: Hybrid (Recommended)

### Architecture

Combine both approaches for maximum flexibility:

1. **Internal**: Transfer layer uses dry-events for event publishing
2. **External API**: Provide convenience methods for simple DI-based usage
3. **Power users**: Can subscribe directly to events for advanced scenarios

```ruby
# Transfer layer publishes events (Approach 2)
class Transfer::HTTP
  include Dry::Events::Publisher[:transfer]
  register_event('download.started')
  register_event('download.progress')
  register_event('download.completed')

  # Convenience method for simple DI usage (Approach 1 API)
  def initialize(progress: nil)
    subscribe(ProgressAdapter.new(progress)) if progress
  end
end

# Adapter converts events to Progress::Base interface
class ProgressAdapter
  def initialize(progress)
    @progress = progress
  end

  def on_download_started(event)
    @progress.on_start(event[:total_size])
  end

  def on_download_progress(event)
    @progress.on_progress(event[:current_size])
  end

  def on_download_completed(event)
    @progress.on_complete
  end
end

# Simple usage (looks like Approach 1)
http = Transfer::HTTP.new(progress: Progress::Bar.new)

# Advanced usage (direct event subscription)
http = Transfer::HTTP.new
http.subscribe(MyLogger.new)
http.subscribe(MyMetrics.new)
http.subscribe(Progress::Bar.new)  # if it implements event interface
```

### Pros

- **Best of both worlds**: Simple API for common cases, powerful events for advanced cases
- **Gradual adoption**: Start simple, add subscribers as needed
- **Future-proof**: Easy to add monitoring, APM, distributed tracing later
- **Backward compatible**: Can maintain Progress::Base interface

### Cons

- **Adapter overhead**: Small additional complexity for ProgressAdapter
- **Two APIs**: Developers need to know both styles exist

## Recommendation

**Choose Approach 3 (Hybrid)** for the following reasons:

1. **Phase 3.1 (Now)**: Implement dry-events in Transfer layer, provide Progress::Base adapter
2. **Phase 3.1**: Implement Progress::Bar using Progress::Base interface (simple)
3. **Phase 6+ (Later)**: Add logging, metrics subscribers as event listeners
4. **Future**: Add dry-monitor instrumentation for APM/distributed tracing

### Implementation Order

```ruby
# Phase 3.1 - Foundation
- Add dry-events ~> 1.1 dependency
- Implement Transfer::HTTP with event publishing
- Implement Progress::Base interface
- Implement ProgressAdapter for DI compatibility
- Implement Progress::Bar using Progress::Base

# Phase 6 - CLI (use simple DI API)
- CLI commands use: Transfer::HTTP.new(progress: Progress::Bar.new)

# Future - Advanced monitoring
- Add dry-monitor ~> 1.0 dependency
- Implement logging subscriber
- Implement metrics collector subscriber
- Add instrumentation wrapper
```

## Decision

- [ ] Approach 1: Progress::Base only (simple, limited)
- [x] Approach 2: dry-events only (powerful, flexible) **← ADOPTED**
- [ ] Approach 3: Hybrid (unnecessary for new implementation)

### Rationale for Approach 2

Since this is a new implementation, there is **no need for backward compatibility** with a Progress::Base interface.

Key points:
- Progress::Bar can be implemented directly as an event listener
- No adapter layer needed (simpler architecture)
- Event-driven design provides extensibility from the start
- Consistent with dry-rb ecosystem (dry-container, dry-configurable, dry-auto_inject already in use)
- Easy to add logging, metrics, APM subscribers later

### Implementation Decision (2025-11-09)

**Adopt Approach 2 (dry-events)** with the following implementation:

```ruby
# Transfer layer publishes events
class Transfer::HTTP
  include Dry::Events::Publisher[:transfer]

  register_event('download.started')
  register_event('download.progress')
  register_event('download.completed')
end

# Progress::Bar as direct event listener
class Progress::Bar
  def on_download_started(event)
  def on_download_progress(event)
  def on_download_completed(event)
end
```

No Progress::Base interface or adapter needed.

### Implementation Update (2025-11-14)

**Refactored to Presenter pattern** with separated concerns:

```ruby
# Progress presenters - display layer
class Progress::Presenter
  def initialize(title:, output:)
  def start(total:, format: nil)
  def update(current)
  def finish
end

class Progress::MultiPresenter
  def register(name, title:) -> PresenterAdapter
end

class Progress::PresenterAdapter
  def initialize(tty_bar)
  def start(total:, format: nil)
  def update(current)
  def finish
end

# Event handlers - application layer
class Progress::DownloadHandler
  def initialize(presenter)
  def on_download_started(event)
    @presenter.start(total: event[:total_size], format: "...")
  end
  def on_download_progress(event)
    @presenter.update(event[:current_size])
  end
  def on_download_completed(event)
    @presenter.finish
  end
end

class Progress::UploadHandler
  # Similar structure for upload events
end

# Usage in Download command
multi_presenter = Progress::MultiPresenter.new(title: "Downloads")
presenter = multi_presenter.register(mod_name, title: file_name)
handler = Progress::DownloadHandler.new(presenter)
http.subscribe(handler)
```

Key improvements:
- **Separation of concerns**: Presenters handle display, handlers handle events
- **Presenter pattern**: Abstract interface allows different implementations
- **Adapter pattern**: PresenterAdapter bridges TTY::ProgressBar interface
- **Reusability**: Handlers work with any presenter implementation
- **Testability**: Easy to mock presenters in handler tests

## References

- [dry-events documentation](https://dry-rb.org/gems/dry-events/1.0/)
- [dry-monitor documentation](https://dry-rb.org/gems/dry-monitor/1.0/)
- [Transfer Components](components/transfer.md)
