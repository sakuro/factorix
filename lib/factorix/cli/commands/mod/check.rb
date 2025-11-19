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
          include Factorix::Import[:logger, :runtime]

          desc "Validate MOD dependencies"

          # Execute the check command
          #
          # @return [void]
          def call(**)
            mod_list_path = runtime.mod_list_path

            # Load mod-list.json
            mod_list = Factorix::MODList.load(from: mod_list_path)

            # Get all installed MODs
            installed_mods = Factorix::InstalledMOD.all

            # Build dependency graph
            graph = Factorix::Dependency::Graph::Builder.build(
              installed_mods:,
              mod_list:
            )

            # Validate
            validator = Factorix::Dependency::Validator.new(
              graph,
              mod_list:,
              all_installed_mods: installed_mods
            )
            result = validator.validate

            # Display results
            display_result(result, graph)

            # Exit with error code if validation failed
            exit(1) unless result.valid?
          end

          private def display_result(result, graph)
            say "Validating MOD dependencies..."

            if result.valid? && !result.warnings?
              display_success_messages
            end

            display_warnings(result) if result.warnings?
            display_errors(result) if result.errors?
            display_suggestions(result) if result.suggestions?

            display_summary(result, graph)
          end

          private def display_success_messages
            say <<~MESSAGE
              ✅ All enabled MODs have their required dependencies satisfied
              ✅ No circular dependencies detected
              ✅ No conflicting MODs are enabled simultaneously
            MESSAGE
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
            suggestions_text = result.suggestions.map {|s| "  - #{s.message}" }.join("\n")
            say <<~MESSAGE
              💡 Suggestions:
              #{suggestions_text}
            MESSAGE
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

            say "Summary: #{parts.join(", ")}"
          end
        end
      end
    end
  end
end
