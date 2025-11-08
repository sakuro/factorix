# frozen_string_literal: true

module Factorix
  # Base error class for Factorix
  class Error < StandardError; end

  # =====================================
  # Infrastructure layer errors
  # =====================================
  class InfrastructureError < Error; end

  # File format related errors
  class FileFormatError < InfrastructureError; end
  class UnknownPropertyType < FileFormatError; end
end
