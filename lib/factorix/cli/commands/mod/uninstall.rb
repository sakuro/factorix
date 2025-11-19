# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Uninstall MODs from mod directory
        class Uninstall < Base
          include Confirmable
          include DependencyGraphSupport

          require_game_stopped!

          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Factorix::Import[:logger, :runtime]

          desc "Uninstall MODs from mod directory"

          argument :mod_specs, type: :array, required: true, desc: "MOD specifications (name@version or name)"

          # Internal structure to represent an uninstall target
          UninstallTarget = Data.define(:mod, :version) {
            # Check if a specific version is targeted
            # @return [Boolean] true if version is specified
            def versioned? = !version.nil?

            # String representation of the uninstall target
            # @return [String] MOD name with optional version (e.g., "mod-a@1.0.0" or "mod-a")
            def to_s = versioned? ? "#{mod.name}@#{version}" : mod.name
          }
          # Execute the uninstall command
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @return [void]
          def call(mod_specs:, **)
            # Load current state
            graph, mod_list, installed_mods = load_current_state

            # Parse mod specs to extract MOD and optional version
            uninstall_targets = mod_specs.map {|spec| parse_mod_spec(spec) }

            # Plan uninstall
            targets_to_uninstall = plan_uninstall(uninstall_targets, graph, installed_mods)

            if targets_to_uninstall.empty?
              say "No MODs to uninstall"
              return
            end

            # Show plan and confirm
            show_plan(targets_to_uninstall)
            return unless confirm?("Do you want to uninstall these MODs?")

            # Execute uninstall
            execute_uninstall(targets_to_uninstall, installed_mods, mod_list)

            # Save mod-list.json
            mod_list.save(to: runtime.mod_list_path)
            say "✓ Saved mod-list.json"
          end

          private def parse_mod_spec(mod_spec)
            if mod_spec.include?("@")
              mod_name, version_str = mod_spec.split("@", 2)
              mod = Factorix::MOD[name: mod_name]
              version = Factorix::Types::MODVersion.from_string(version_str)
              UninstallTarget.new(mod:, version:)
            else
              mod = Factorix::MOD[name: mod_spec]
              UninstallTarget.new(mod:, version: nil)
            end
          end

          private def plan_uninstall(targets, graph, installed_mods)
            targets.filter_map do |target|
              validate_uninstall_target(target, graph, installed_mods)
            end
          end

          # Validate a single uninstall target
          #
          # @param target [UninstallTarget] Target to validate
          # @param graph [Dependency::Graph] Dependency graph
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @return [UninstallTarget, nil] The target if valid, nil if should be skipped
          private def validate_uninstall_target(target, graph, installed_mods)
            mod = target.mod

            # Check if base/expansion
            raise Factorix::Error, "Cannot uninstall base MOD" if mod.base?
            raise Factorix::Error, "Cannot uninstall expansion MOD: #{mod.name}" if mod.expansion?

            # Check if installed
            unless graph.node?(mod)
              say "MOD not installed: #{mod.name}", prefix: :warn
              logger.debug("MOD not installed", mod_name: mod.name)
              return nil
            end

            # For versioned uninstall, check if the specific version exists
            if target.versioned? && !version_installed?(target, installed_mods)
              say "MOD version not installed: #{target}", prefix: :warn
              logger.debug("MOD version not installed", target: target.to_s)
              return nil
            end

            # Check for enabled dependents
            check_dependents_with_version(target, graph, installed_mods)

            target
          end

          # Check if a specific version is installed
          #
          # @param target [UninstallTarget] Target with version
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @return [Boolean] true if version is installed
          private def version_installed?(target, installed_mods)
            installed_mods.any? {|im| im.mod == target.mod && im.version == target.version }
          end

          # Check for enabled dependents considering remaining versions
          #
          # @param target [UninstallTarget] Target to check
          # @param graph [Dependency::Graph] Dependency graph
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @return [void]
          # @raise [Factorix::Error] if dependencies cannot be satisfied after uninstall
          private def check_dependents_with_version(target, graph, installed_mods)
            mod = target.mod
            dependents = find_enabled_dependents(mod, graph)
            return if dependents.none?

            # Find versions that will remain after this uninstall
            remaining_versions = if target.versioned?
                                   installed_mods.select {|im| im.mod == mod && im.version != target.version }
                                 else
                                   [] # Uninstalling all versions
                                 end

            # Check each dependent to see if remaining versions can satisfy their requirements
            unsatisfied_dependents = []

            dependents.each do |dependent_mod|
              # Find dependency edges from dependent to target MOD
              edges = graph.edges_from(dependent_mod).select {|edge|
                edge.to_mod == mod && edge.required?
              }

              edges.each do |edge|
                # Check if any remaining version satisfies this requirement
                can_satisfy = remaining_versions.any? {|im| edge.satisfied_by?(im.version) }

                unsatisfied_dependents << dependent_mod unless can_satisfy
              end
            end

            return if unsatisfied_dependents.empty?

            dependent_names = unsatisfied_dependents.uniq.map!(&:name)
            raise Factorix::Error,
              "Cannot uninstall #{target}: " \
              "the following enabled MODs depend on it: #{dependent_names.join(", ")}"
          end

          # Find all enabled MODs that have a required dependency on the given MOD
          #
          # @param mod [MOD] The MOD to find dependents for
          # @param graph [Dependency::Graph] Dependency graph
          # @return [Array<MOD>] Array of MODs that depend on the given MOD
          private def find_enabled_dependents(mod, graph)
            dependents = []

            graph.nodes.each do |node|
              next unless node.enabled?

              graph.edges_from(node.mod).each do |edge|
                next unless edge.required? && edge.to_mod == mod

                dependents << node.mod
                break
              end
            end

            dependents
          end

          # Show the uninstall plan
          #
          # @param targets [Array<UninstallTarget>] Targets to uninstall
          # @return [void]
          private def show_plan(targets)
            say "Planning to uninstall #{targets.size} MOD#{"s" unless targets.size == 1}:"
            targets.each do |target|
              say "  - #{target}"
            end
          end

          # Execute the uninstall
          #
          # @param targets [Array<UninstallTarget>] Targets to uninstall
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @param mod_list [MODList] The MOD list
          # @return [void]
          private def execute_uninstall(targets, installed_mods, mod_list)
            targets.each do |target|
              mod = target.mod

              # Find versions to uninstall
              mod_versions = if target.versioned?
                               # Uninstall only the specified version
                               installed_mods.select {|im|
                                 im.mod == mod && im.version == target.version
                               }
                             else
                               # Uninstall all versions
                               installed_mods.select {|im| im.mod == mod }
                             end

              say "Uninstalling #{mod_versions.size} version(s) of #{target}"

              # Remove versions from file system
              mod_versions.each do |installed_mod|
                remove_mod_files(installed_mod)
              end

              # Remove from mod-list.json if appropriate
              should_remove_from_list = if target.versioned?
                                          # Only remove if mod-list references this version or if no versions remain
                                          remaining_versions = installed_mods.select {|im|
                                            im.mod == mod && !mod_versions.include?(im)
                                          }
                                          remaining_versions.empty?
                                        else
                                          # Always remove when uninstalling all versions
                                          true
                                        end

              if should_remove_from_list && mod_list.exist?(mod)
                mod_list.remove(mod)
                say "✓ Removed #{mod.name} from mod-list.json"
              end
            end
          end

          # Remove MOD files from the file system
          #
          # @param installed_mod [InstalledMOD] The installed MOD to remove
          # @return [void]
          private def remove_mod_files(installed_mod)
            path = installed_mod.path

            if installed_mod.form == Factorix::InstalledMOD::ZIP_FORM
              path.delete
              logger.info(
                "Removed ZIP file",
                mod_name: installed_mod.mod.name,
                version: installed_mod.version.to_s
              )
            elsif installed_mod.form == Factorix::InstalledMOD::DIRECTORY_FORM
              path.rmtree
              logger.info(
                "Removed directory",
                mod_name: installed_mod.mod.name,
                version: installed_mod.version.to_s
              )
            end
          end
        end
      end
    end
  end
end
