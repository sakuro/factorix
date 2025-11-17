# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Disable MODs in mod-list.json with reverse dependency resolution
        class Disable < Base
          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          include Factorix::Import[:logger]

          desc "Disable MODs in mod-list.json (recursively disables dependent MODs)"

          argument :mod_names, type: :array, required: true, desc: "MOD names to disable"

          # Execute the disable command
          #
          # @param mod_names [Array<String>] MOD names to disable
          # @return [void]
          def call(mod_names:, **)
            runtime = Factorix::Runtime.detect
            mod_list_path = runtime.mod_list_path
            mod_dir = runtime.mod_dir

            # Load mod-list.json
            mod_list = Factorix::MODList.load(from: mod_list_path)

            # Scan installed MODs
            installed_mods = Factorix::InstalledMOD.scan(mod_dir)
            installed_by_mod = installed_mods.to_h {|im| [im.mod, im] }

            # Convert mod names to MOD objects
            mods = mod_names.map {|name| Factorix::MOD[name:] }

            # Phase 1: Planning - collect all changes
            to_disable = Set.new
            processed = Set.new

            mods.each do |mod|
              collect_to_disable(
                mod,
                mod_list,
                installed_by_mod,
                to_disable,
                processed
              )
            end

            # Log the plan and execute
            say "Planning to disable #{to_disable.size} MOD(s)"

            # Phase 2: Execution - apply all changes
            to_disable.each do |mod|
              logger.debug("  Will disable", mod_name: mod.name)
              mod_list.disable(mod)
              say "✓ Disabled #{mod.name}"
              logger.debug("Disabled MOD", mod_name: mod.name)
            end

            # Save mod-list.json
            mod_list.save(to: mod_list_path)
            say "✓ Saved mod-list.json"
            logger.debug("Saved mod-list.json")
          end

          private def collect_to_disable(mod, mod_list, installed_by_mod, to_disable, processed)
            # Skip if already processed
            return if processed.include?(mod)

            processed.add(mod)

            # Can't disable base MOD
            if mod.base?
              logger.error("Cannot disable base MOD", mod_name: mod.name)
              raise Factorix::Error, "Cannot disable base MOD"
            end

            # Can't disable expansion MODs
            if mod.expansion?
              logger.error("Cannot disable expansion MOD", mod_name: mod.name)
              raise Factorix::Error, "Cannot disable expansion MOD: #{mod.name}"
            end

            # Check if MOD is in mod-list.json
            unless mod_list.exist?(mod)
              logger.warn("MOD not in mod-list.json, skipping", mod_name: mod.name)
              return
            end

            # Skip if already disabled
            unless mod_list.enabled?(mod)
              logger.debug("MOD already disabled", mod_name: mod.name)
              return
            end

            # Find all enabled MODs that depend on this MOD (reverse dependencies)
            dependent_mods = find_dependent_mods(mod, mod_list, installed_by_mod)

            # Recursively collect dependent MODs to disable
            dependent_mods.each do |dependent_mod|
              logger.debug(
                "Found dependent MOD",
                dependent: dependent_mod.name,
                dependency: mod.name
              )
              collect_to_disable(
                dependent_mod,
                mod_list,
                installed_by_mod,
                to_disable,
                processed
              )
            end

            # Add this MOD to the disable set
            to_disable.add(mod)
          end

          # Find all enabled MODs that have a required dependency on the given MOD
          #
          # @param mod [MOD] The MOD to find dependents for
          # @param mod_list [MODList] The MOD list
          # @param installed_by_mod [Hash{MOD => InstalledMOD}] Installed MODs indexed by MOD
          # @return [Array<MOD>] Array of MODs that depend on the given MOD
          private def find_dependent_mods(mod, mod_list, installed_by_mod)
            dependent_mods = []

            # Check all enabled MODs in mod-list.json
            mod_list.each do |check_mod, state|
              next unless state.enabled?
              next unless installed_by_mod[check_mod]

              # Parse dependencies
              dependencies = parse_dependencies(installed_by_mod[check_mod].info)

              # Check if this MOD has a required dependency on the target MOD
              has_dependency = dependencies.any? {|dep|
                dep.required? && dep.mod == mod
              }

              dependent_mods << check_mod if has_dependency
            end

            dependent_mods
          end

          # Parse dependencies from info.json
          #
          # @param info [Types::InfoJSON] The info.json data
          # @return [Array<Dependency::Entry>] Array of dependencies
          private def parse_dependencies(info)
            return [] unless info.dependencies

            # InfoJSON already parses dependencies, so just return them
            info.dependencies
          end
        end
      end
    end
  end
end
