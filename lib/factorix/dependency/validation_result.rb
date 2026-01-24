# frozen_string_literal: true

module Factorix
  module Dependency
    # Represents the result of MOD dependency validation
    #
    # Holds errors and warnings found during validation.
    class ValidationResult
      Error = Data.define(:type, :message, :mod, :dependency)

      # Validation error information
      #
      # Represents an error found during dependency validation.
      class Error
        # @!attribute [r] type
        #   @return [Symbol] error type
        # @!attribute [r] message
        #   @return [String] error message
        # @!attribute [r] mod
        #   @return [Factorix::MOD, nil] related MOD
        # @!attribute [r] dependency
        #   @return [Factorix::MOD, nil] dependency MOD
      end

      Warning = Data.define(:type, :message, :mod)

      # Validation warning information
      #
      # Represents a warning found during dependency validation.
      class Warning
        # @!attribute [r] type
        #   @return [Symbol] warning type
        # @!attribute [r] message
        #   @return [String] warning message
        # @!attribute [r] mod
        #   @return [Factorix::MOD, nil] related MOD
      end

      Suggestion = Data.define(:message, :mod, :version)

      # Validation suggestion information
      #
      # Represents a suggestion for resolving dependency issues.
      class Suggestion
        # @!attribute [r] message
        #   @return [String] suggestion message
        # @!attribute [r] mod
        #   @return [Factorix::MOD] related MOD
        # @!attribute [r] version
        #   @return [Factorix::MODVersion] suggested version
      end

      # Error types
      MISSING_DEPENDENCY = :missing_dependency
      public_constant :MISSING_DEPENDENCY
      DISABLED_DEPENDENCY = :disabled_dependency
      public_constant :DISABLED_DEPENDENCY
      VERSION_MISMATCH = :version_mismatch
      public_constant :VERSION_MISMATCH
      CONFLICT = :conflict
      public_constant :CONFLICT
      CIRCULAR_DEPENDENCY = :circular_dependency
      public_constant :CIRCULAR_DEPENDENCY

      # Warning types
      MOD_IN_LIST_NOT_INSTALLED = :mod_in_list_not_installed
      public_constant :MOD_IN_LIST_NOT_INSTALLED
      MOD_INSTALLED_NOT_IN_LIST = :mod_installed_not_in_list
      public_constant :MOD_INSTALLED_NOT_IN_LIST

      def initialize
        @errors = []
        @warnings = []
        @suggestions = []
      end

      # Add an error
      #
      # @param type [Symbol] Error type
      # @param message [String] Error message
      # @param mod [Factorix::MOD, nil] Related MOD
      # @param dependency [Factorix::MOD, nil] Dependency MOD
      # @return [void]
      def add_error(type:, message:, mod: nil, dependency: nil) = @errors << Error[type:, message:, mod:, dependency:]

      # Add a warning
      #
      # @param type [Symbol] Warning type
      # @param message [String] Warning message
      # @param mod [Factorix::MOD, nil] Related MOD
      # @return [void]
      def add_warning(type:, message:, mod: nil) = @warnings << Warning[type:, message:, mod:]

      # Add a suggestion
      #
      # @param message [String] Suggestion message
      # @param mod [Factorix::MOD] Related MOD
      # @param version [Factorix::MODVersion] Suggested version
      # @return [void]
      def add_suggestion(message:, mod:, version:) = @suggestions << Suggestion[message:, mod:, version:]

      # Get all errors
      #
      # @return [Array<Error>]
      attr_reader :errors

      # Get all warnings
      #
      # @return [Array<Warning>]
      attr_reader :warnings

      # Get all suggestions
      #
      # @return [Array<Suggestion>]
      attr_reader :suggestions

      # Check if there are any errors
      #
      # @return [Boolean]
      def errors? = !@errors.empty?

      # Check if there are any warnings
      #
      # @return [Boolean]
      def warnings? = !@warnings.empty?

      # Check if there are any suggestions
      #
      # @return [Boolean]
      def suggestions? = !@suggestions.empty?

      # Check if validation passed (no errors)
      #
      # @return [Boolean]
      def valid? = !errors?
    end
  end
end
