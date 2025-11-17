# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Enable MODs in mod-list.json with dependency resolution
        class Enable < Base
          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          include Factorix::Import[:logger]

          desc "Enable MODs in mod-list.json (recursively enables dependencies)"

          argument :mod_names, type: :array, required: true, desc: "MOD names to enable"

          # Execute the enable command
          #
          # @param mod_names [Array<String>] MOD names to enable
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
            to_enable = Set.new
            to_disable = Set.new
            processed = Set.new

            mods.each do |mod|
              collect_changes(
                mod,
                mod_list,
                installed_by_mod,
                to_enable,
                to_disable,
                processed
              )
            end

            # Log the plan
            say "Planning to enable #{to_enable.size} MOD(s)"
            to_enable.each {|m| logger.debug("  Will enable", mod_name: m.name) }

            if to_disable.any?
              say "Planning to disable #{to_disable.size} conflicting MOD(s)"
              to_disable.each {|m| logger.debug("  Will disable", mod_name: m.name) }
            end

            # Phase 2: Execution - apply all changes
            to_disable.each do |mod|
              mod_list.disable(mod)
              say "✓ Disabled #{mod.name}"
              logger.debug("Disabled conflicting MOD", mod_name: mod.name)
            end

            to_enable.each do |mod|
              mod_list.enable(mod)
              say "✓ Enabled #{mod.name}"
              logger.debug("Enabled MOD", mod_name: mod.name)
            end

            # Save mod-list.json
            mod_list.save(to: mod_list_path)
            say "✓ Saved mod-list.json"
            logger.debug("Saved mod-list.json")
          end

          private def collect_changes(mod, mod_list, installed_by_mod, to_enable, to_disable, processed)
            # Skip if already processed
            return if processed.include?(mod)

            processed.add(mod)

            # Check if MOD is in mod-list.json
            unless mod_list.exist?(mod)
              logger.warn("MOD not in mod-list.json, skipping", mod_name: mod.name)
              return
            end

            # Skip if already enabled
            if mod_list.enabled?(mod)
              logger.debug("MOD already enabled", mod_name: mod.name)
              return
            end

            # Get installed MOD to read dependencies
            installed_mod = installed_by_mod[mod]
            unless installed_mod
              logger.warn("MOD not installed, cannot enable", mod_name: mod.name)
              return
            end

            # Parse dependencies from info.json
            dependencies = parse_dependencies(installed_mod.info)

            # Collect incompatible MODs (conflicts) to disable
            dependencies.select(&:incompatible?).each do |dep|
              next if dep.mod.base? # Can't disable base

              next unless mod_list.exist?(dep.mod) && mod_list.enabled?(dep.mod)

              logger.debug(
                "Found conflict",
                conflicting_mod: dep.mod.name,
                required_by: mod.name
              )
              to_disable.add(dep.mod)
            end

            # Recursively collect required dependencies to enable
            dependencies.select(&:required?).each do |dep|
              next if dep.mod.base? # Base is always enabled
              next if dep.mod.expansion? # Expansions are managed separately

              # Validate version requirement if the dependency is installed
              if installed_by_mod[dep.mod]
                installed_version = installed_by_mod[dep.mod].version
                unless dep.satisfied_by?(installed_version)
                  logger.error(
                    "Dependency version requirement not satisfied",
                    mod_name: mod.name,
                    dependency: dep.mod.name,
                    required: dep.version_requirement.to_s,
                    installed: installed_version.to_s
                  )
                  raise Factorix::Error, "Cannot enable #{mod.name}: dependency #{dep.mod.name} version requirement not satisfied"
                end
              end

              # Recursively collect changes for the dependency
              collect_changes(
                dep.mod,
                mod_list,
                installed_by_mod,
                to_enable,
                to_disable,
                processed
              )
            end

            # Add this MOD to the enable set
            to_enable.add(mod)
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
