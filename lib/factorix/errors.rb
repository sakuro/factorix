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

  # HTTP errors
  class HTTPError < InfrastructureError; end
  class HTTPClientError < HTTPError; end
  class HTTPServerError < HTTPError; end

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

  # Dependency validation errors
  class ValidationError < DomainError; end

  # Game state errors
  class GameRunningError < DomainError; end
end
