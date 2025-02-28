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

  # Raised when an invalid section name is encountered in mod settings.
  class InvalidModSectionError < Error
    def initialize(section_name)
      super("Invalid mod section name: #{section_name}")
    end
  end

  # Raised when a section is not found in mod settings.
  class ModSectionNotFoundError < Error
    def initialize(section_name)
      super("Mod section not found: #{section_name}")
    end
  end
end
