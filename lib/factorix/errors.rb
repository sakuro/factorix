# frozen_string_literal: true

module Factorix
  # Base error class for Factorix
  class Error < StandardError; end

  # =====================================
  # Infrastructure layer errors
  # =====================================
  class InfrastructureError < Error; end

  # HTTP errors
  class HTTPError < InfrastructureError; end
  class HTTPClientError < HTTPError; end
  class HTTPServerError < HTTPError; end

  # File format related errors
  class FileFormatError < InfrastructureError; end
  class UnknownPropertyType < FileFormatError; end

  # MOD list file errors
  class InvalidMODListError < FileFormatError; end

  # =====================================
  # Domain layer errors
  # =====================================
  class DomainError < Error; end

  # MOD errors
  class MODNotFoundError < DomainError; end
end
