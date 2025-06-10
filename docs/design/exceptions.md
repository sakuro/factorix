# Factorix Exception Hierarchy Design

## Overview

This document describes the redesigned exception hierarchy for Factorix, a Ruby CLI tool for managing Factorio MODs. The new hierarchy provides clear separation of concerns and improved error handling capabilities.

## Design Principles

1. **Layered Architecture**: Separate infrastructure, ModPortal API, and application concerns
2. **Clear Responsibility**: Each exception class has a well-defined purpose
3. **Extensibility**: Easy to add new exception types
4. **Consistency**: Uniform error handling patterns across the codebase

## Complete Exception Hierarchy

```ruby
module Factorix
  # Base error class for Factorix
  class Error < StandardError; end

  # =====================================
  # Infrastructure layer errors
  # =====================================
  class InfrastructureError < Error; end

  # Network related errors
  class NetworkError < InfrastructureError; end
  class NetworkTimeoutError < NetworkError; end
  class NetworkConnectionError < NetworkError; end
  class SSLTLSError < NetworkError; end

  # HTTP specific errors
  class HTTPError < NetworkError; end
  class HTTPClientError < HTTPError; end      # 4xx series
  class HTTPServerError < HTTPError; end      # 5xx series
  class HTTPTimeoutError < HTTPError; end
  class HTTPConnectionError < HTTPError; end
  class HTTPResponseError < HTTPError; end    # Invalid response format

  # File system related errors
  class FileSystemError < InfrastructureError; end
  class FileNotFoundError < FileSystemError; end
  class DirectoryNotFoundError < FileSystemError; end
  class DirectoryNotWritableError < FileSystemError; end
  class FileExistsError < FileSystemError; end

  # File format related errors
  class FileFormatError < InfrastructureError; end
  class SHA1MismatchError < FileFormatError; end
  class ExtraDataError < FileFormatError; end
  class InvalidModSectionError < FileFormatError; end
  class UnknownPropertyTypeError < FileFormatError; end

  # Runtime platform errors
  class RuntimeError < InfrastructureError; end
  class UnsupportedPlatformError < RuntimeError; end
  class AlreadyRunningError < RuntimeError; end

  # =====================================
  # ModPortal API layer errors
  # =====================================
  class ModPortalAPIError < Error; end
  class ModPortalRequestError < ModPortalAPIError; end      # Request transmission error
  class ModPortalResponseError < ModPortalAPIError; end     # Response parsing error
  class ModPortalValidationError < ModPortalAPIError; end   # Parameter validation error
  class ModPortalRateLimitError < ModPortalAPIError; end    # Rate limiting error
  class ModPortalAuthenticationError < ModPortalAPIError; end # Authentication error

  # =====================================
  # Application layer errors
  # =====================================
  class ApplicationError < Error; end

  # MOD related errors
  class ModError < ApplicationError; end
  class ModNotFoundError < ModError; end
  class ModSectionNotFoundError < ModError; end
  class DownloadError < ModError; end

  # CLI related errors
  class CLIError < ApplicationError; end

  # Validation errors
  class ValidationError < ApplicationError; end
  class InvalidParameterError < ValidationError; end
end
```

## Layer Descriptions

### Infrastructure Layer (`InfrastructureError`)

Handles system-level dependencies and external resources.

#### Network Errors (`NetworkError`)
- **Purpose**: General network communication issues
- **Examples**: Connection failures, timeouts, SSL/TLS errors

#### HTTP Errors (`HTTPError`)
- **Purpose**: HTTP-specific communication issues
- **Sub-categories**:
  - `HTTPClientError`: 4xx status codes (client-side issues)
  - `HTTPServerError`: 5xx status codes (server-side issues)
  - `HTTPTimeoutError`: HTTP request timeouts
  - `HTTPConnectionError`: HTTP connection failures
  - `HTTPResponseError`: Invalid response format

#### File System Errors (`FileSystemError`)
- **Purpose**: File and directory operations
- **Examples**: File not found, permission issues, directory creation failures

#### File Format Errors (`FileFormatError`)
- **Purpose**: File content validation and parsing
- **Examples**: SHA1 mismatches, invalid MOD sections, unknown property types

#### Runtime Errors (`RuntimeError`)
- **Purpose**: Platform and execution environment issues
- **Examples**: Unsupported platform, already running process

### ModPortal API Layer (`ModPortalAPIError`)

Dedicated to Factorio's ModPortal API interactions.

- **`ModPortalRequestError`**: HTTP request transmission failures
- **`ModPortalResponseError`**: Response parsing and validation failures
- **`ModPortalValidationError`**: API parameter validation failures
- **`ModPortalRateLimitError`**: API rate limiting issues
- **`ModPortalAuthenticationError`**: API authentication failures

### Application Layer (`ApplicationError`)

Application-specific business logic errors.

#### MOD Errors (`ModError`)
- **Purpose**: MOD-related business logic
- **Examples**: MOD not found, MOD section not found, download failures

#### CLI Errors (`CLIError`)
- **Purpose**: Command-line interface operations
- **Examples**: Invalid commands, missing arguments

#### Validation Errors (`ValidationError`)
- **Purpose**: Input validation and parameter checking
- **Examples**: Invalid parameters, validation rule violations

## Key Differences from Previous Design

### Error Reclassification

| Error Class | Previous Location | New Location | Reason |
|-------------|------------------|--------------|---------|
| `InvalidModSectionError` | `ModError` | `FileFormatError` | File content validation error |
| `ModSectionNotFoundError` | `ModError` | `ModError` | Business logic error |
| `SHA1MismatchError` | `CLIError` | `FileFormatError` | File integrity validation |
| `UnknownPropertyTypeError` | `ModError` | `FileFormatError` | File format parsing error |
| `ExtraDataError` | `CLIError` | `FileFormatError` | File format validation error |

### New Exception Types

- `HTTPClientError` / `HTTPServerError`: HTTP status code-specific handling
- `ModPortalRateLimitError`: API rate limiting support
- `ModPortalAuthenticationError`: API authentication support

## Error Handling Strategies

### By Layer

1. **Infrastructure Errors**: System configuration checks, retry mechanisms
2. **ModPortal API Errors**: Service status checks, alternative approaches
3. **Application Errors**: User intervention, configuration changes

### By Error Type

- **Network Errors**: Retry with exponential backoff
- **HTTP Client Errors (4xx)**: Immediate failure, user notification
- **HTTP Server Errors (5xx)**: Retry after delay
- **File Format Errors**: Detailed error messages for debugging
- **Validation Errors**: User-friendly error messages with correction hints

## Implementation Benefits

1. **Clear Separation of Concerns**: Each layer has distinct responsibilities
2. **Improved Error Handling**: Layer-specific handling strategies
3. **Better Debugging**: Error classification aids in problem identification
4. **Enhanced Extensibility**: Easy addition of new error types
5. **Consistent Patterns**: Uniform error handling across the application

## Migration Considerations

When implementing this design:

1. Update all `raise` statements to use new exception classes
2. Update all `rescue` clauses to catch appropriate exception types
3. Update RBS type definitions in `sig/factorix/errors.rbs`
4. Update test cases to expect new exception types
5. Review retry strategies based on new error classification

## Future Enhancements

- **Structured Error Data**: Add structured data to exceptions for better error reporting
- **Error Codes**: Introduce error codes for programmatic error handling
- **Localization**: Support for multiple languages in error messages
- **Metrics Integration**: Track error occurrences for monitoring and alerting
