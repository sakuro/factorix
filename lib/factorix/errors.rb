# frozen_string_literal: true

module Factorix
  # Base error class for Factorix.
  class Error < StandardError; end

  # Raised when a MOD is not found.
  class ModNotFoundError < Error; end

  # Raised when an unknown property type is encountered during serialization/deserialization.
  class UnknownPropertyType < Error; end

  # Raised when an invalid section name is encountered in MOD settings.
  class InvalidModSectionError < Error; end

  # Raised when a section is not found in MOD settings.
  class ModSectionNotFoundError < Error; end

  # Error raised when download fails
  class DownloadError < Error; end
end
