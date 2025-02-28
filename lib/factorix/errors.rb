# frozen_string_literal: true

module Factorix
  # Base error class for Factorix.
  class Error < StandardError; end

  # Raised when a MOD is not found.
  class ModNotFoundError < Error
    def initialize(mod)
      super("MOD not found: #{mod}")
    end
  end

  # Raised when an unknown property type is encountered during serialization/deserialization.
  class UnknownPropertyType < Error
    def initialize(type)
      super("Unknown property type: #{type}")
    end
  end
end
