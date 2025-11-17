# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Validate MOD dependencies without making changes
        class Check < Dry::CLI::Command
          prepend CommonOptions

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
            mod_dir = runtime.mod_dir
            data_dir = runtime.data_dir

            # Load mod-list.json
            mod_list = Factorix::MODList.load(from: mod_list_path)

            # Scan installed MODs (including base/expansion from data directory)
            installed_mods = Factorix::InstalledMOD.scan(mod_dir, data_dir:)

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
            logger.info("Validating MOD dependencies...")
            logger.info("")

            if result.valid? && !result.warnings?
              display_success_messages
            end

            display_warnings(result) if result.warnings?
            display_errors(result) if result.errors?
            display_suggestions(result) if result.suggestions?

            logger.info("")
            display_summary(result, graph)
          end

          private def display_success_messages
            logger.info("✅ All enabled MODs have their required dependencies satisfied")
            logger.info("✅ No circular dependencies detected")
            logger.info("✅ No conflicting MODs are enabled simultaneously")
          end

          private def display_warnings(result)
            logger.info("")
            logger.warn("⚠️  Warnings:")
            result.warnings.each do |warning|
              logger.warn("  - #{warning.message}")
            end
          end

          private def display_errors(result)
            logger.info("")
            logger.error("❌ Errors:")
            result.errors.each do |error|
              logger.error("  - #{error.message}")
            end
          end

          private def display_suggestions(result)
            logger.info("")
            logger.info("💡 Suggestions:")
            result.suggestions.each do |suggestion|
              logger.info("  - #{suggestion.message}")
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

            logger.info("Summary: #{parts.join(", ")}")
          end
        end
      end
    end
  end
end
