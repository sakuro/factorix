# frozen_string_literal: true

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
  class HTTPClientError < HTTPError; end
  class HTTPServerError < HTTPError; end
  class HTTPTimeoutError < HTTPError; end
  class HTTPConnectionError < HTTPError; end
  class HTTPResponseError < HTTPError; end

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
  class UnknownPropertyType < FileFormatError; end

  # Template related errors
  class TemplateError < InfrastructureError; end

  # Runtime platform errors
  class RuntimeError < InfrastructureError; end
  class UnsupportedPlatformError < RuntimeError; end
  class AlreadyRunningError < RuntimeError; end

  # =====================================
  # ModPortal API layer errors
  # =====================================
  class ModPortalAPIError < Error; end
  class ModPortalRequestError < ModPortalAPIError; end
  class ModPortalResponseError < ModPortalAPIError; end
  class ModPortalValidationError < ModPortalAPIError; end
  class ModPortalRateLimitError < ModPortalAPIError; end
  class ModPortalAuthenticationError < ModPortalAPIError; end

  # =====================================
  # Application layer errors
  # =====================================
  class ApplicationError < Error; end

  # MOD related errors
  class ModError < ApplicationError; end
  class ModNotFoundError < ModError; end
  class ModSectionNotFoundError < ModError; end
  class DownloadError < ModError; end

  # MOD list related errors
  class ModNotInListError < ModError; end

  # CLI related errors
  class CLIError < ApplicationError; end

  # Validation errors
  class ValidationError < ApplicationError; end
  class InvalidParameterError < ValidationError; end
end
