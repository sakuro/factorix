# frozen_string_literal: true

require_relative "../errors"

module Factorix
  module ModPortal
    # Base class for all ModPortal related errors
    class Error < Factorix::Error; end

    # Raised when request to ModPortal API fails
    class RequestError < Error; end

    # Raised when response from ModPortal API cannot be parsed
    class ResponseError < Error; end

    # Raised when parameters are invalid
    class ValidationError < Error; end
  end
end
