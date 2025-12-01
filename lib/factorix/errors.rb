# frozen_string_literal: true

module Factorix
  # Base error class for Factorix
  class Error < StandardError; end

  # =====================================
  # Infrastructure layer errors
  # =====================================
  class InfrastructureError < Error; end

  # Configuration errors
  class ConfigurationError < InfrastructureError; end

  # Credential/environment variable errors
  class CredentialError < ConfigurationError; end

  # Shell/completion errors
  class ShellError < ConfigurationError; end

  # Directory not found errors
  class DirectoryNotFoundError < ConfigurationError; end

  # URL related errors
  class URLError < InfrastructureError; end

  # Platform-specific errors (WSL, etc.)
  class PlatformError < InfrastructureError; end

  # Unsupported platform errors
  class UnsupportedPlatformError < PlatformError; end

  # HTTP errors
  class HTTPError < InfrastructureError; end

  # HTTP client error (4xx) with optional API error details
  class HTTPClientError < HTTPError
    attr_reader :api_error
    attr_reader :api_message

    def initialize(message=nil, api_error: nil, api_message: nil)
      @api_error = api_error
      @api_message = api_message
      super(message)
    end
  end

  class HTTPNotFoundError < HTTPClientError; end
  class HTTPServerError < HTTPError; end

  # Digest verification errors
  class DigestMismatchError < InfrastructureError; end

  # External command not found
  class CommandNotFoundError < InfrastructureError; end

  # File format related errors
  class FileFormatError < InfrastructureError; end

  # Binary format errors
  class BinaryFormatError < FileFormatError; end
  class InvalidLengthError < BinaryFormatError; end
  class UnknownPropertyType < BinaryFormatError; end
  class ExtraDataError < BinaryFormatError; end

  # MOD settings file errors
  class MODSectionNotFoundError < FileFormatError; end

  # =====================================
  # Domain layer errors
  # =====================================
  class DomainError < Error; end

  # MOD errors
  class MODNotFoundError < DomainError; end
  class MODNotOnPortalError < MODNotFoundError; end
  class BundledMODError < DomainError; end

  # MOD conflict errors
  class MODConflictError < DomainError; end

  # MOD settings errors
  class MODSettingsError < DomainError; end

  # Invalid operation errors (e.g., cannot disable base MOD)
  class InvalidOperationError < DomainError; end

  # CLI argument validation errors
  class InvalidArgumentError < DomainError; end

  # Version parsing errors
  class VersionParseError < DomainError; end

  # Dependency parsing errors
  class DependencyParseError < DomainError; end

  # Dependency graph errors
  class DependencyGraphError < DomainError; end

  # Dependency errors
  class DependencyError < DomainError; end
  class CircularDependencyError < DependencyError; end
  class DependencyMissingError < DependencyError; end
  class DependencyVersionError < DependencyError; end
  class DependencyViolationError < DependencyError; end

  # Dependency validation errors
  class ValidationError < DomainError; end

  # Game state errors
  class GameRunningError < DomainError; end
end
