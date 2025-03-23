# frozen_string_literal: true

require_relative "../errors"

module Factorix
  module ModPortal
    # Base class for all ModPortal related errors.
    # Provides a common ancestor for all errors that can occur during ModPortal operations
    class Error < Factorix::Error; end

    # Raised when request to ModPortal API fails.
    # This includes network errors, timeouts, and HTTP errors
    class RequestError < Error; end

    # Raised when response from ModPortal API cannot be parsed.
    # This typically occurs when the response is not valid JSON or has unexpected structure
    class ResponseError < Error; end

    # Raised when parameters are invalid.
    # This occurs when API method parameters don't meet the required format or constraints
    class ValidationError < Error; end
  end
end
