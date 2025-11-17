# frozen_string_literal: true

module Factorix
  module Dependency
    # Represents the result of MOD dependency validation
    #
    # Holds errors and warnings found during validation.
    class ValidationResult
      # Validation error
      Error = Data.define(
        :type,        # Symbol - error type
        :message,     # String - error message
        :mod,         # MOD (optional) - related MOD
        :dependency   # MOD (optional) - dependency MOD
      )

      # Validation warning
      Warning = Data.define(
        :type,        # Symbol - warning type
        :message,     # String - warning message
        :mod          # MOD (optional) - related MOD
      )

      # Error types
      MISSING_DEPENDENCY = :missing_dependency
      DISABLED_DEPENDENCY = :disabled_dependency
      VERSION_MISMATCH = :version_mismatch
      CONFLICT = :conflict
      CIRCULAR_DEPENDENCY = :circular_dependency
      public_constant :MISSING_DEPENDENCY, :DISABLED_DEPENDENCY, :VERSION_MISMATCH, :CONFLICT, :CIRCULAR_DEPENDENCY

      # Warning types
      MOD_IN_LIST_NOT_INSTALLED = :mod_in_list_not_installed
      MOD_INSTALLED_NOT_IN_LIST = :mod_installed_not_in_list
      public_constant :MOD_IN_LIST_NOT_INSTALLED, :MOD_INSTALLED_NOT_IN_LIST

      def initialize
        @errors = []
        @warnings = []
      end

      # Add an error
      #
      # @param type [Symbol] Error type
      # @param message [String] Error message
      # @param mod [Factorix::MOD, nil] Related MOD
      # @param dependency [Factorix::MOD, nil] Dependency MOD
      # @return [void]
      def add_error(type:, message:, mod: nil, dependency: nil)
        @errors << Error.new(type:, message:, mod:, dependency:)
      end

      # Add a warning
      #
      # @param type [Symbol] Warning type
      # @param message [String] Warning message
      # @param mod [Factorix::MOD, nil] Related MOD
      # @return [void]
      def add_warning(type:, message:, mod: nil)
        @warnings << Warning.new(type:, message:, mod:)
      end

      # Get all errors
      #
      # @return [Array<Error>]
      attr_reader :errors

      # Get all warnings
      #
      # @return [Array<Warning>]
      attr_reader :warnings

      # Check if there are any errors
      #
      # @return [Boolean]
      def errors?
        !@errors.empty?
      end

      # Check if there are any warnings
      #
      # @return [Boolean]
      def warnings?
        !@warnings.empty?
      end

      # Check if validation passed (no errors)
      #
      # @return [Boolean]
      def valid?
        !errors?
      end
    end
  end
end
