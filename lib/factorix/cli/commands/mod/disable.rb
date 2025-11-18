# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Disable MODs in mod-list.json with reverse dependency resolution
        class Disable < Base
          include Confirmable

          require_game_stopped!

          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Factorix::Import[:logger, :runtime]

          desc "Disable MODs in mod-list.json (recursively disables dependent MODs)"

          argument :mod_names, type: :array, required: true, desc: "MOD names to disable"
          option :only,
            type: :boolean,
            default: false,
            desc: "Only disable specified MODs (error if other enabled MODs depend on them)"

          # Execute the disable command
          #
          # @param mod_names [Array<String>] MOD names to disable
          # @param only [Boolean] Only disable specified MODs without dependents
          # @return [void]
          def call(mod_names:, only: false, **)
            mod_list_path = runtime.mod_list_path

            # Load current state
            mod_list = Factorix::MODList.load(from: mod_list_path)

            # Build dependency graph
            graph = Factorix::Dependency::Graph::Builder.build(
              installed_mods: Factorix::InstalledMOD.all,
              mod_list:
            )

            # Convert mod names to MOD objects
            target_mods = mod_names.map {|name| Factorix::MOD[name:] }

            # Validate target MODs exist and can be disabled
            validate_target_mods(target_mods, graph)

            # Determine MODs to disable
            mods_to_disable = if only
                                plan_only_mode(target_mods, graph)
                              else
                                plan_with_dependents(target_mods, graph)
                              end

            # Show plan to user
            show_plan(mods_to_disable)

            # Return early if nothing to disable
            return if mods_to_disable.empty?

            # Ask for confirmation
            return unless confirm?("Do you want to disable these MODs?")

            # Execute the plan
            execute_plan(mods_to_disable, mod_list)

            # Save mod-list.json
            mod_list.save(to: mod_list_path)
            say "✓ Saved mod-list.json"
            logger.debug("Saved mod-list.json")
          end

          # Validate that all target MODs can be disabled
          #
          # @param target_mods [Array<Factorix::MOD>] MODs to validate
          # @param graph [Factorix::Dependency::Graph] Dependency graph
          # @return [void]
          # @raise [Factorix::Error] if any MOD cannot be disabled
          private def validate_target_mods(target_mods, graph)
            target_mods.each do |mod|
              # Check if base MOD
              if mod.base?
                raise Factorix::Error, "Cannot disable base MOD"
              end

              # Check if expansion MOD
              if mod.expansion?
                raise Factorix::Error, "Cannot disable expansion MOD: #{mod.name}"
              end

              # Check if MOD exists in graph (is installed)
              unless graph.node?(mod)
                say "MOD not installed, skipping: #{mod.name}", prefix: :warn
                logger.debug("MOD not installed", mod_name: mod.name)
              end
            end
          end

          # Plan disable in --only mode
          #
          # Verifies no enabled MODs depend on the target MODs and returns only the specified MODs.
          #
          # @param target_mods [Array<Factorix::MOD>] MODs to disable
          # @param graph [Factorix::Dependency::Graph] Dependency graph
          # @return [Array<Factorix::MOD>] MODs to disable
          # @raise [Factorix::Error] if any enabled MOD depends on a target MOD
          private def plan_only_mode(target_mods, graph)
            mods_to_disable = []

            target_mods.each do |mod|
              node = graph.node(mod)

              # Skip if not installed
              unless node
                logger.debug("MOD not installed", mod_name: mod.name)
                next
              end

              # Skip if already disabled
              unless node.enabled?
                logger.debug("MOD already disabled", mod_name: mod.name)
                next
              end

              # Check if any enabled MOD depends on this MOD
              dependents = find_enabled_dependents(mod, graph)
              if dependents.any?
                dependent_names = dependents.map(&:name).join(", ")
                raise Factorix::Error,
                  "Cannot disable #{mod.name} with --only: other enabled MODs depend on it (#{dependent_names})"
              end

              mods_to_disable << mod
            end

            mods_to_disable
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

              # Skip if not installed
              unless node
                logger.debug("MOD not installed", mod_name: mod.name)
                next
              end

              # Skip if already disabled
              unless node.enabled?
                logger.debug("MOD already disabled", mod_name: mod.name)
                next
              end

              # Skip if already in the disable set
              next if mods_to_disable.include?(mod)

              # Find all enabled MODs that depend on this MOD
              dependents = find_enabled_dependents(mod, graph)

              # Add dependents to process queue
              dependents.each do |dependent_mod|
                logger.debug(
                  "Found dependent MOD",
                  dependent: dependent_mod.name,
                  dependency: mod.name
                )
                to_process << dependent_mod unless mods_to_disable.include?(dependent_mod)
              end

              # Add this MOD to the disable set
              mods_to_disable.add(mod)
            end

            mods_to_disable.to_a
          end

          # Find all enabled MODs that have a required dependency on the given MOD
          #
          # @param mod [Factorix::MOD] The MOD to find dependents for
          # @param graph [Factorix::Dependency::Graph] Dependency graph
          # @return [Array<Factorix::MOD>] MODs that depend on the given MOD
          private def find_enabled_dependents(mod, graph)
            dependents = []

            # Check all nodes in the graph
            graph.nodes.each do |node|
              next unless node.enabled?

              # Check if this node has a required dependency on the target MOD
              graph.edges_from(node.mod).each do |edge|
                next unless edge.required?
                next unless edge.to_mod == mod

                dependents << node.mod
                break
              end
            end

            dependents
          end

          # Show the disable plan to user
          #
          # @param mods_to_disable [Array<Factorix::MOD>] MODs to disable
          # @return [void]
          private def show_plan(mods_to_disable)
            if mods_to_disable.empty?
              say "All specified MODs are already disabled"
              return
            end

            say "Planning to disable #{mods_to_disable.size} MOD(s):"
            mods_to_disable.each do |mod|
              say "  - #{mod.name}"
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
              say "✓ Disabled #{mod.name}"
              logger.debug("Disabled MOD", mod_name: mod.name)
            end
          end
        end
      end
    end
  end
end
