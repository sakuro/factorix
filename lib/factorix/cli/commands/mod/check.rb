# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Validate MOD dependencies without making changes
        class Check < Base
          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Import[:logger, :runtime]

          desc "Validate MOD dependencies"

          example [
            "   # Validate all MOD dependencies"
          ]

          # Execute the check command
          #
          # @return [void]
          def call(**)
            mod_list = MODList.load
            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Scanning MOD(s)", output: $stderr)
            handler = Progress::ScanHandler.new(presenter)
            installed_mods = InstalledMOD.all(handler:)
            graph = Dependency::Graph::Builder.build(installed_mods:, mod_list:)

            validator = Dependency::Validator.new(graph:, mod_list:, installed_mods:)
            result = validator.validate

            display_result(result, graph)

            raise ValidationError, "MOD dependency validation failed" unless result.valid?
          end

          private def display_result(result, graph)
            say "Validating MOD dependencies...", prefix: :info

            if result.valid? && !result.warnings?
              display_success_messages
            end

            display_warnings(result) if result.warnings?
            display_errors(result) if result.errors?
            display_suggestions(result) if result.suggestions?

            display_summary(result, graph)
          end

          private def display_success_messages
            say "All enabled MOD(s) have their required dependencies satisfied", prefix: :success
            say "No circular dependencies detected", prefix: :success
            say "No conflicting MOD(s) are enabled simultaneously", prefix: :success
          end

          private def display_warnings(result)
            say "Warnings:", prefix: :warn
            result.warnings.each do |warning|
              say "  - #{warning.message}"
            end
          end

          private def display_errors(result)
            say "Errors:", prefix: :error
            result.errors.each do |error|
              say "  - #{error.message}"
            end
          end

          private def display_suggestions(result)
            say "Suggestions:", prefix: :info
            result.suggestions.each do |suggestion|
              say "  - #{suggestion.message}"
            end
          end

          private def display_summary(result, graph)
            enabled_count = graph.nodes.count(&:enabled?)
            parts = ["#{enabled_count} enabled MOD#{"s" unless enabled_count == 1}"]

            if result.errors?
              parts << "#{result.errors.size} error#{"s" unless result.errors.size == 1}"
            end

            if result.warnings?
              parts << "#{result.warnings.size} warning#{"s" unless result.warnings.size == 1}"
            end

            say "Summary: #{parts.join(", ")}", prefix: :info
          end
        end
      end
    end
  end
end
