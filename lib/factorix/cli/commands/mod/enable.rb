# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Enable MODs in mod-list.json with dependency resolution
        class Enable < Base
          confirmable!
          require_game_stopped!

          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Import[:logger, :runtime]

          desc "Enable MOD(s) in mod-list.json (recursively enables dependencies)"

          example [
            "some-mod         # Enable single MOD",
            "mod-a mod-b      # Enable multiple MOD(s)"
          ]

          argument :mod_names, type: :array, required: true, desc: "MOD names to enable"

          # Execute the enable command
          #
          # @param mod_names [Array<String>] MOD names to enable
          # @return [void]
          def call(mod_names:, **)
            # Load current state (without validation to allow fixing issues)
            state = MODInstallationState.new

            # Convert MOD names to MOD objects
            target_mods = mod_names.map {|name| Factorix::MOD[name:] }

            # Validate target MODs exist
            validate_target_mods_exist(target_mods, state.graph)

            # Determine MODs to enable
            mods_to_enable = plan_with_dependencies(target_mods, state.graph)

            # Validate the plan (check for conflicts)
            validate_plan(mods_to_enable, state.graph)

            # Show plan to user
            show_plan(mods_to_enable)

            # Return early if nothing to enable
            return if mods_to_enable.empty?

            # Ask for confirmation
            return unless confirm?("Do you want to enable these MOD(s)?")

            # Execute the plan
            execute_plan(mods_to_enable, state.mod_list)

            # Save mod-list.json
            state.mod_list.save
            say "Enabled #{mods_to_enable.size} MOD(s)", prefix: :success
            say "Saved mod-list.json", prefix: :success
            logger.debug("Saved mod-list.json")
          end

          # Validate that all target MODs are installed
          #
          # @param target_mods [Array<Factorix::MOD>] MODs to validate
          # @param graph [Factorix::Dependency::Graph] Dependency graph
          # @return [void]
          # @raise [Factorix::Error] if any MOD is not installed
          private def validate_target_mods_exist(target_mods, graph)
            target_mods.each do |mod|
              unless graph.node?(mod)
                raise Error, "MOD '#{mod}' is not installed"
              end
            end
          end

          # Plan enable with automatic dependency resolution
          #
          # @param target_mods [Array<Factorix::MOD>] MODs to enable
          # @param graph [Factorix::Dependency::Graph] Dependency graph
          # @return [Array<Factorix::MOD>] MODs to enable (including dependencies)
          # @raise [Factorix::Error] if any dependency is missing or has version mismatch
          private def plan_with_dependencies(target_mods, graph)
            mods_to_enable = Set.new
            to_process = target_mods.dup

            while (mod = to_process.shift)
              node = graph.node(mod)

              if node.enabled?
                logger.debug("MOD already enabled", mod_name: mod.name)
                next
              end

              next if mods_to_enable.include?(mod)

              mods_to_enable.add(mod)

              graph.edges_from(mod).select(&:required?).each do |edge|
                next if edge.to_mod.base?

                dep_mod = edge.to_mod
                dep_node = graph.node(dep_mod)

                unless dep_node
                  raise Error,
                    "MOD '#{mod}' requires '#{dep_mod}' which is not installed"
                end
                unless edge.satisfied_by?(dep_node.version)
                  raise Error,
                    "Cannot enable #{mod}: dependency #{dep_mod} version requirement not satisfied " \
                    "(required: #{edge.version_requirement}, installed: #{dep_node.version})"
                end

                # Add to process queue if not already enabled
                to_process << dep_mod unless dep_node.enabled?
              end
            end

            mods_to_enable.to_a
          end

          # Validate the enable plan
          #
          # Checks for conflicts with currently enabled MODs or MODs in the enable plan.
          #
          # @param mods_to_enable [Array<Factorix::MOD>] MODs to enable
          # @param graph [Factorix::Dependency::Graph] Dependency graph
          # @return [void]
          # @raise [Factorix::Error] if any conflict is detected
          private def validate_plan(mods_to_enable, graph)
            mods_to_enable_set = Set.new(mods_to_enable)

            mods_to_enable.each do |mod|
              # Check outgoing incompatibility edges (this MOD conflicts with others)
              graph.edges_from(mod).select(&:incompatible?).each do |edge|
                conflict_node = graph.node(edge.to_mod)

                # Check if conflicting MOD is currently enabled
                if conflict_node&.enabled?
                  raise Error,
                    "Cannot enable #{mod}: conflicts with #{edge.to_mod} which is currently enabled"
                end

                # Check if conflicting MOD is in the enable plan
                if mods_to_enable_set.include?(edge.to_mod)
                  raise Error,
                    "Cannot enable #{mod}: conflicts with #{edge.to_mod} which is also being enabled"
                end
              end

              # Check incoming incompatibility edges (other MODs conflict with this one)
              graph.edges_to(mod).select(&:incompatible?).each do |edge|
                conflict_node = graph.node(edge.from_mod)

                # Check if conflicting MOD is currently enabled
                if conflict_node&.enabled?
                  raise Error,
                    "Cannot enable #{mod}: conflicts with #{edge.from_mod} which is currently enabled"
                end

                # Check if conflicting MOD is in the enable plan
                if mods_to_enable_set.include?(edge.from_mod)
                  raise Error,
                    "Cannot enable #{mod}: conflicts with #{edge.from_mod} which is also being enabled"
                end
              end
            end
          end

          # Show the enable plan to user
          #
          # @param mods_to_enable [Array<Factorix::MOD>] MODs to enable
          # @return [void]
          private def show_plan(mods_to_enable)
            if mods_to_enable.empty?
              say "All specified MOD(s) are already enabled", prefix: :info
              return
            end

            say "Planning to enable #{mods_to_enable.size} MOD(s):", prefix: :info
            mods_to_enable.each do |mod|
              say "  - #{mod}"
            end
          end

          # Execute the enable plan
          #
          # @param mods_to_enable [Array<Factorix::MOD>] MODs to enable
          # @param mod_list [Factorix::MODList] MOD list to modify
          # @return [void]
          private def execute_plan(mods_to_enable, mod_list)
            return if mods_to_enable.empty?

            mods_to_enable.each do |mod|
              mod_list.enable(mod)
              say "Enabled #{mod}", prefix: :success
              logger.debug("Enabled MOD", mod_name: mod.name)
            end
          end
        end
      end
    end
  end
end
