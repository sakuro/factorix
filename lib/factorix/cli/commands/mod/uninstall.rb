# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Uninstall MODs from MOD directory
        class Uninstall < Base
          confirmable!
          require_game_stopped!

          include DependencyGraphSupport

          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Import[:logger, :runtime]

          desc "Uninstall MOD(s) from MOD directory"

          example [
            "some-mod         # Uninstall all versions of MOD",
            "some-mod@1.2.0   # Uninstall specific version",
            "--all            # Uninstall all MOD(s)"
          ]

          argument :mod_specs, type: :array, required: false, desc: "MOD specifications (name@version or name)"
          option :all, type: :flag, default: false, desc: "Uninstall all MOD(s) (base remains enabled, expansions disabled, others removed)"

          # Execute the uninstall command
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param all [Boolean] Uninstall all MODs
          # @return [void]
          def call(mod_specs: [], all: false, **)
            # Validate arguments
            if all && mod_specs.any?
              raise Error, "Cannot specify MOD names with --all option"
            end

            unless all || mod_specs.any?
              raise Error, "Must specify MOD names or use --all option"
            end

            # Load current state (without validation to allow fixing issues)
            graph, mod_list, installed_mods = load_current_state

            # Determine uninstall targets
            uninstall_targets = if all
                                  plan_uninstall_all(graph, installed_mods)
                                else
                                  # Parse mod specs to extract MOD and optional version
                                  mod_specs.map {|spec| parse_mod_spec(spec) }
                                end

            targets_to_uninstall = plan_uninstall(uninstall_targets, graph, installed_mods, all:)

            if all
              expansions_to_disable = graph.nodes.count {|node|
                mod = node.mod
                mod.expansion? && mod_list.exist?(mod) && mod_list.enabled?(mod)
              }

              if targets_to_uninstall.empty? && expansions_to_disable.zero?
                say "No MOD(s) to uninstall or disable", prefix: :info
                return
              end
            elsif targets_to_uninstall.empty?
              say "No MOD(s) to uninstall", prefix: :info
              return
            end

            show_plan(targets_to_uninstall, all:, graph:, mod_list:)
            return unless confirm?("Do you want to uninstall these MOD(s)?")

            execute_uninstall(targets_to_uninstall, installed_mods, mod_list)
            disable_expansion_mods(graph, mod_list) if all
            mod_list.save(runtime.mod_list_path)
            say "Uninstalled #{targets_to_uninstall.size} MOD(s)", prefix: :success
            say "Saved mod-list.json", prefix: :success
          end

          # Plan uninstall all MODs
          #
          # @param graph [Dependency::Graph] Dependency graph
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @return [Array<Hash>] Uninstall targets in reverse dependency order
          private def plan_uninstall_all(graph, _installed_mods)
            # Reverse topological order ensures dependents are uninstalled before their dependencies
            ordered_mods = graph.topological_order
            mods_in_reverse_order = ordered_mods.reverse

            mods_in_reverse_order.filter_map do |mod|
              next if mod.base?

              # Expansion MODs are disabled but not uninstalled
              {mod:, version: nil} unless mod.expansion?
            end
          end

          private def parse_mod_spec(mod_spec)
            if mod_spec.include?("@")
              mod_name, version_str = mod_spec.split("@", 2)
              mod = Factorix::MOD[name: mod_name]
              version = MODVersion.from_string(version_str)
              {mod:, version:}
            else
              mod = Factorix::MOD[name: mod_spec]
              {mod:, version: nil}
            end
          end

          private def plan_uninstall(targets, graph, installed_mods, all: false)
            targets.filter_map do |target|
              validate_uninstall_target(target, graph, installed_mods, all:)
            end
          end

          # Validate a single uninstall target
          #
          # @param target [Hash] Target to validate ({mod:, version:})
          # @param graph [Dependency::Graph] Dependency graph
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @param all [Boolean] Whether this is part of --all uninstall
          # @return [Hash, nil] The target if valid, nil if should be skipped
          private def validate_uninstall_target(target, graph, installed_mods, all: false)
            mod = target[:mod]

            # Check if base/expansion
            raise Error, "Cannot uninstall base MOD" if mod.base?
            raise Error, "Cannot uninstall expansion MOD: #{mod}" if mod.expansion?

            # Check if installed
            unless graph.node?(mod)
              say "MOD not installed: #{mod}", prefix: :warn
              logger.debug("MOD not installed", mod_name: mod.name)
              return nil
            end

            if target[:version] && !version_installed?(target, installed_mods)
              say "MOD version not installed: #{format_target(target)}", prefix: :warn
              logger.debug("MOD version not installed", target: format_target(target))
              return nil
            end

            # Skip dependent check for --all since all MODs are being uninstalled
            check_dependents_with_version(target, graph, installed_mods) unless all

            target
          end

          # Check if a specific version is installed
          #
          # @param target [Hash] Target with version ({mod:, version:})
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @return [Boolean] true if version is installed
          private def version_installed?(target, installed_mods)
            installed_mods.any? {|im| im.mod == target[:mod] && im.version == target[:version] }
          end

          # Check for enabled dependents considering remaining versions
          #
          # @param target [Hash] Target to check ({mod:, version:})
          # @param graph [Dependency::Graph] Dependency graph
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @return [void]
          # @raise [Factorix::Error] if dependencies cannot be satisfied after uninstall
          private def check_dependents_with_version(target, graph, installed_mods)
            mod = target[:mod]
            dependents = find_enabled_dependents(mod, graph)
            return if dependents.none?

            # Find versions that will remain after this uninstall
            remaining_versions = if target[:version]
                                   installed_mods.select {|im| im.mod == mod && im.version != target[:version] }
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

            raise Error,
              "Cannot uninstall #{format_target(target)}: " \
              "the following enabled MOD(s) depend on it: #{unsatisfied_dependents.uniq.join(", ")}"
          end

          # Show the uninstall plan
          #
          # @param targets [Array<Hash>] Targets to uninstall
          # @param all [Boolean] Whether --all was specified
          # @param graph [Dependency::Graph] Dependency graph
          # @param mod_list [MODList] The MOD list
          # @return [void]
          private def show_plan(targets, all: false, graph: nil, mod_list: nil)
            say "Planning to uninstall #{targets.size} MOD(s):", prefix: :info
            targets.each do |target|
              say "  - #{format_target(target)}"
            end

            # If --all, also show expansion MODs to be disabled
            return unless all && graph && mod_list

            expansions_to_disable = graph.nodes.filter_map {|node|
              mod = node.mod
              mod if mod.expansion? && mod_list.exist?(mod) && mod_list.enabled?(mod)
            }

            return if expansions_to_disable.none?

            say "Expansion MOD(s) to be disabled:", prefix: :info
            expansions_to_disable.each do |mod|
              say "  - #{mod}"
            end
          end

          # Execute the uninstall
          #
          # @param targets [Array<Hash>] Targets to uninstall
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @param mod_list [MODList] The MOD list
          # @return [void]
          private def execute_uninstall(targets, installed_mods, mod_list)
            targets.each do |target|
              mod = target[:mod]

              # Find versions to uninstall
              mod_versions = if target[:version]
                               # Uninstall only the specified version
                               installed_mods.select {|im|
                                 im.mod == mod && im.version == target[:version]
                               }
                             else
                               # Uninstall all versions
                               installed_mods.select {|im| im.mod == mod }
                             end

              # Remove versions from file system
              mod_versions.each do |installed_mod|
                remove_mod_files(installed_mod)
              end

              # Remove from mod-list.json if appropriate
              should_remove_from_list = if target[:version]
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
                say "Removed #{mod} from mod-list.json", prefix: :success
              end
            end
          end

          # Disable expansion MODs in mod-list.json
          #
          # @param graph [Dependency::Graph] Dependency graph
          # @param mod_list [MODList] The MOD list
          # @return [void]
          private def disable_expansion_mods(graph, mod_list)
            graph.nodes.each do |node|
              mod = node.mod
              next unless mod.expansion?
              next unless mod_list.exist?(mod) && mod_list.enabled?(mod)

              mod_list.disable(mod)
              say "Disabled expansion MOD: #{mod}", prefix: :success
              logger.info("Disabled expansion MOD", mod_name: mod.name)
            end
          end

          # Remove MOD files from the file system
          #
          # @param installed_mod [InstalledMOD] The installed MOD to remove
          # @return [void]
          private def remove_mod_files(installed_mod)
            path = installed_mod.path

            if installed_mod.form == InstalledMOD::ZIP_FORM
              path.delete
              logger.info("Removed ZIP file", mod_name: installed_mod.mod.name, version: installed_mod.version.to_s)
            elsif installed_mod.form == InstalledMOD::DIRECTORY_FORM
              path.rmtree
              logger.info("Removed directory", mod_name: installed_mod.mod.name, version: installed_mod.version.to_s)
            end
          end

          # Format uninstall target for display
          #
          # @param target [Hash] Target to format ({mod:, version:})
          # @return [String] Formatted string (e.g., "mod-a@1.0.0" or "mod-a")
          private def format_target(target)
            target[:version] ? "#{target[:mod]}@#{target[:version]}" : target[:mod].to_s
          end
        end
      end
    end
  end
end
