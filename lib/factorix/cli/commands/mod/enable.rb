# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Enable MODs in mod-list.json with dependency resolution
        class Enable < Base
          include Confirmable
          prepend RequiresGameStopped

          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Factorix::Import[:logger, :runtime]

          desc "Enable MODs in mod-list.json (recursively enables dependencies)"

          argument :mod_names, type: :array, required: true, desc: "MOD names to enable"
          option :only,
            type: :boolean,
            default: false,
            desc: "Only enable specified MODs (error if dependencies are not already enabled)"

          # Execute the enable command
          #
          # @param mod_names [Array<String>] MOD names to enable
          # @param only [Boolean] Only enable specified MODs without dependencies
          # @return [void]
          def call(mod_names:, only: false, **)
            mod_list_path = runtime.mod_list_path
            mod_dir = runtime.mod_dir

            # Load current state
            mod_list = Factorix::MODList.load(from: mod_list_path)
            installed_mods = Factorix::InstalledMOD.scan(mod_dir)

            # Build dependency graph
            graph = Factorix::Dependency::Graph::Builder.build(
              installed_mods:,
              mod_list:
            )

            # Convert mod names to MOD objects
            target_mods = mod_names.map {|name| Factorix::MOD[name:] }

            # Validate target MODs exist
            validate_target_mods_exist(target_mods, graph)

            # Determine MODs to enable
            mods_to_enable = if only
                               plan_only_mode(target_mods, graph)
                             else
                               plan_with_dependencies(target_mods, graph)
                             end

            # Validate the plan (check for conflicts)
            validate_plan(mods_to_enable, graph)

            # Show plan to user
            show_plan(mods_to_enable)

            # Return early if nothing to enable
            return if mods_to_enable.empty?

            # Ask for confirmation
            return unless confirm?("Do you want to enable these MODs?")

            # Execute the plan
            execute_plan(mods_to_enable, mod_list)

            # Save mod-list.json
            mod_list.save(to: mod_list_path)
            say "✓ Saved mod-list.json"
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
                raise Factorix::Error, "MOD '#{mod.name}' is not installed"
              end
            end
          end

          # Plan enable in --only mode
          #
          # Verifies all dependencies are already enabled and returns only the specified MODs.
          #
          # @param target_mods [Array<Factorix::MOD>] MODs to enable
          # @param graph [Factorix::Dependency::Graph] Dependency graph
          # @return [Array<Factorix::MOD>] MODs to enable
          # @raise [Factorix::Error] if any dependency is not enabled
          private def plan_only_mode(target_mods, graph)
            mods_to_enable = []

            target_mods.each do |mod|
              node = graph.node(mod)

              # Skip if already enabled
              if node.enabled?
                logger.debug("MOD already enabled", mod_name: mod.name)
                next
              end

              # Check all required dependencies are enabled
              graph.edges_from(mod).select(&:required?).each do |edge|
                next if edge.to_mod.base? # Base is always available

                dep_node = graph.node(edge.to_mod)

                unless dep_node
                  raise Factorix::Error,
                    "Cannot enable #{mod.name} with --only: dependency #{edge.to_mod.name} is not installed"
                end

                unless dep_node.enabled?
                  raise Factorix::Error,
                    "Cannot enable #{mod.name} with --only: dependency #{edge.to_mod.name} is not enabled"
                end

                # Validate version requirement
                next if edge.satisfied_by?(dep_node.version)

                raise Factorix::Error,
                  "Cannot enable #{mod.name}: dependency #{edge.to_mod.name} version requirement not satisfied " \
                  "(required: #{edge.version_requirement}, installed: #{dep_node.version})"
              end

              mods_to_enable << mod
            end

            mods_to_enable
          end

          # Plan enable with automatic dependency resolution
          #
          # Uses graph traversal to find all dependencies recursively.
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

              # Skip if already enabled
              if node.enabled?
                logger.debug("MOD already enabled", mod_name: mod.name)
                next
              end

              # Skip if already in the enable set
              next if mods_to_enable.include?(mod)

              # Add to enable set
              mods_to_enable.add(mod)

              # Add all required dependencies to process
              graph.edges_from(mod).select(&:required?).each do |edge|
                next if edge.to_mod.base? # Base is always available

                dep_mod = edge.to_mod
                dep_node = graph.node(dep_mod)

                # Validate dependency exists
                unless dep_node
                  raise Factorix::Error,
                    "MOD '#{mod.name}' requires '#{dep_mod.name}' which is not installed"
                end

                # Validate version requirement
                unless edge.satisfied_by?(dep_node.version)
                  raise Factorix::Error,
                    "Cannot enable #{mod.name}: dependency #{dep_mod.name} version requirement not satisfied " \
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
              graph.edges_from(mod).select(&:incompatible?).each do |edge|
                conflict_node = graph.node(edge.to_mod)

                # Check if conflicting MOD is currently enabled
                if conflict_node&.enabled?
                  raise Factorix::Error,
                    "Cannot enable #{mod.name}: conflicts with #{edge.to_mod.name} which is currently enabled"
                end

                # Check if conflicting MOD is in the enable plan
                if mods_to_enable_set.include?(edge.to_mod)
                  raise Factorix::Error,
                    "Cannot enable #{mod.name}: conflicts with #{edge.to_mod.name} which is also being enabled"
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
              say "All specified MODs are already enabled"
              return
            end

            say "Planning to enable #{mods_to_enable.size} MOD(s):"
            mods_to_enable.each do |mod|
              say "  - #{mod.name}"
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
              say "✓ Enabled #{mod.name}"
              logger.debug("Enabled MOD", mod_name: mod.name)
            end
          end
        end
      end
    end
  end
end
