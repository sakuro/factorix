# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Disable MODs in mod-list.json with reverse dependency resolution
        class Disable < Base
          include Confirmable
          include DependencyGraphSupport

          require_game_stopped!

          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Import[:logger, :runtime]

          desc "Disable MODs in mod-list.json (recursively disables dependent MODs)"

          argument :mod_names, type: :array, required: true, desc: "MOD names to disable"

          # Execute the disable command
          #
          # @param mod_names [Array<String>] MOD names to disable
          # @return [void]
          def call(mod_names:, **)
            # Load current state (without validation to allow fixing issues)
            graph, mod_list, _installed_mods = load_current_state

            # Convert mod names to MOD objects
            target_mods = mod_names.map {|name| Factorix::MOD[name:] }

            # Validate target MODs exist and can be disabled
            validate_target_mods(target_mods, graph)

            # Determine MODs to disable
            mods_to_disable = plan_with_dependents(target_mods, graph)

            # Show plan to user
            show_plan(mods_to_disable)

            # Return early if nothing to disable
            return if mods_to_disable.empty?

            # Ask for confirmation
            return unless confirm?("Do you want to disable these MODs?")

            # Execute the plan
            execute_plan(mods_to_disable, mod_list)

            # Save mod-list.json
            mod_list.save(to: runtime.mod_list_path)
            say "Saved mod-list.json", prefix: :success
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
                raise Error, "Cannot disable base MOD"
              end

              # Check if MOD exists in graph (is installed)
              unless graph.node?(mod)
                say "MOD not installed, skipping: #{mod.name}", prefix: :warn
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
              say "Disabled #{mod.name}", prefix: :success
              logger.debug("Disabled MOD", mod_name: mod.name)
            end
          end
        end
      end
    end
  end
end
