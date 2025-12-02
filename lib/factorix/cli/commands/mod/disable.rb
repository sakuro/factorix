# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Disable MODs in mod-list.json with reverse dependency resolution
        class Disable < Base
          confirmable!
          require_game_stopped!
          backup_support!

          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Import[:logger, :runtime]

          desc "Disable MOD(s) in mod-list.json (recursively disables dependent MOD(s))"

          example [
            "some-mod         # Disable single MOD",
            "mod-a mod-b      # Disable multiple MOD(s)",
            "--all            # Disable all MOD(s) except base"
          ]

          argument :mod_names, type: :array, required: false, desc: "MOD names to disable"

          option :all, type: :flag, default: false, desc: "Disable all MOD(s) (except base)"

          # Execute the disable command
          #
          # @param mod_names [Array<String>] MOD names to disable
          # @param all [Boolean] Whether to disable all MODs
          # @return [void]
          def call(mod_names: [], all: false, **)
            validate_arguments(mod_names, all)

            # Without validation to allow fixing issues
            state = MODInstallationState.new

            target_mods = if all
                            plan_disable_all(state.graph)
                          else
                            mod_names.map {|name| Factorix::MOD[name:] }
                          end

            validate_target_mods(target_mods, state.graph)
            mods_to_disable = plan_with_dependents(target_mods, state.graph)

            show_plan(mods_to_disable)
            return if mods_to_disable.empty?
            return unless confirm?("Do you want to disable these MOD(s)?")

            execute_plan(mods_to_disable, state.mod_list)
            backup_if_exists(runtime.mod_list_path)
            state.mod_list.save
            say "Disabled #{mods_to_disable.size} MOD(s)", prefix: :success
            say "Saved mod-list.json", prefix: :success
            logger.debug("Saved mod-list.json")
          end

          # Validate command arguments
          #
          # @param mod_names [Array<String>] MOD names from argument
          # @param all [Boolean] Whether --all option is specified
          # @return [void]
          # @raise [InvalidArgumentError] if arguments are invalid
          private def validate_arguments(mod_names, all)
            if all && mod_names.any?
              raise InvalidArgumentError, "Cannot specify MOD names with --all option"
            end

            return if all || mod_names.any?

            raise InvalidArgumentError, "Must specify MOD names or use --all option"
          end

          # Plan which MODs to disable when --all is specified
          #
          # @param graph [Factorix::Dependency::Graph] Dependency graph
          # @return [Array<Factorix::MOD>] MODs to disable (all except base)
          private def plan_disable_all(graph)
            graph.nodes.filter_map do |node|
              mod = node.mod
              next if mod.base?
              next unless node.enabled?

              mod
            end
          end

          # Validate that all target MODs can be disabled
          #
          # @param target_mods [Array<Factorix::MOD>] MODs to validate
          # @param graph [Factorix::Dependency::Graph] Dependency graph
          # @return [void]
          # @raise [InvalidOperationError] if any MOD cannot be disabled
          private def validate_target_mods(target_mods, graph)
            target_mods.each do |mod|
              raise InvalidOperationError, "Cannot disable base MOD" if mod.base?

              unless graph.node?(mod)
                say "MOD not installed, skipping: #{mod}", prefix: :warn
                logger.debug("MOD not installed", mod_name: mod.name)
              end
            end
          end

          # Plan disable with automatic dependent resolution
          #
          # Finds all enabled MODs that depend on the target MODs recursively.
          #
          # @param target_mods [Array<Factorix::MOD>] MODs to disable
          # @param graph [Factorix::Dependency::Graph] Dependency graph
          # @return [Array<Factorix::MOD>] MODs to disable (including dependents)
          private def plan_with_dependents(target_mods, graph)
            mods_to_disable = Set.new
            to_process = target_mods.dup

            while (mod = to_process.shift)
              node = graph.node(mod)

              unless node
                logger.debug("MOD not installed", mod_name: mod.name)
                next
              end

              unless node.enabled?
                logger.debug("MOD already disabled", mod_name: mod.name)
                next
              end

              next if mods_to_disable.include?(mod)

              dependents = graph.find_enabled_dependents(mod)

              dependents.each do |dependent_mod|
                logger.debug("Found dependent MOD", dependent: dependent_mod.name, dependency: mod.name)
                to_process << dependent_mod unless mods_to_disable.include?(dependent_mod)
              end

              mods_to_disable.add(mod)
            end

            mods_to_disable.to_a
          end

          # Show the disable plan to user
          #
          # @param mods_to_disable [Array<Factorix::MOD>] MODs to disable
          # @return [void]
          private def show_plan(mods_to_disable)
            if mods_to_disable.empty?
              say "All specified MOD(s) are already disabled", prefix: :info
              return
            end

            say "Planning to disable #{mods_to_disable.size} MOD(s):", prefix: :info
            mods_to_disable.each do |mod|
              say "  - #{mod}"
            end
          end

          # Execute the disable plan
          #
          # @param mods_to_disable [Array<Factorix::MOD>] MODs to disable
          # @param mod_list [Factorix::MODList] MOD list to modify
          # @return [void]
          private def execute_plan(mods_to_disable, mod_list)
            return if mods_to_disable.empty?

            mods_to_disable.each do |mod|
              mod_list.disable(mod)
              say "Disabled #{mod}", prefix: :success
              logger.debug("Disabled MOD", mod_name: mod.name)
            end
          end
        end
      end
    end
  end
end
