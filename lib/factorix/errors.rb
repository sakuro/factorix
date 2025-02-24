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
end
