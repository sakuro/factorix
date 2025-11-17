# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Uninstall MODs from mod directory
        class Uninstall < Dry::CLI::Command
          prepend CommonOptions

          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          include Factorix::Import[:logger]

          desc "Uninstall MODs from mod directory"

          argument :mod_names, type: :array, required: true, desc: "MOD names to uninstall"

          # Execute the uninstall command
          #
          # @param mod_names [Array<String>] MOD names to uninstall
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

            # Uninstall each MOD
            mods.each do |mod|
              uninstall_mod(mod, mod_list, installed_mods, installed_by_mod)
            end

            # Save mod-list.json
            mod_list.save(to: mod_list_path)
            logger.info("Saved mod-list.json")
          end

          private def uninstall_mod(mod, mod_list, installed_mods, installed_by_mod)
            # Can't uninstall base or expansion MODs
            if mod.base?
              logger.error("Cannot uninstall base MOD", mod_name: mod.name)
              raise Factorix::Error, "Cannot uninstall base MOD"
            end

            if mod.expansion?
              logger.error("Cannot uninstall expansion MOD", mod_name: mod.name)
              raise Factorix::Error, "Cannot uninstall expansion MOD: #{mod.name}"
            end

            # Check for dependent MODs
            dependent_mods = find_dependent_mods(mod, mod_list, installed_by_mod)
            if dependent_mods.any?
              logger.error(
                "Cannot uninstall MOD: other enabled MODs depend on it",
                mod_name: mod.name,
                dependent_mods: dependent_mods.map(&:name)
              )
              raise Factorix::Error,
                "Cannot uninstall #{mod.name}: " \
                "the following enabled MODs depend on it: #{dependent_mods.map(&:name).join(", ")}"
            end

            # Find all versions of this MOD
            mod_versions = installed_mods.select {|im| im.mod == mod }

            if mod_versions.empty?
              logger.warn("MOD not installed", mod_name: mod.name)
              return
            end

            logger.info("Uninstalling #{mod_versions.size} version(s) of MOD", mod_name: mod.name)

            # Remove all versions from file system
            mod_versions.each do |installed_mod|
              remove_mod_files(installed_mod)
            end

            # Remove from mod-list.json if present
            return unless mod_list.exist?(mod)

            mod_list.remove(mod)
            logger.info("Removed from mod-list.json", mod_name: mod.name)
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

          # Remove MOD files from the file system
          #
          # @param installed_mod [InstalledMOD] The installed MOD to remove
          # @return [void]
          private def remove_mod_files(installed_mod)
            path = installed_mod.path

            if installed_mod.form == Factorix::InstalledMOD::ZIP_FORM
              # Remove ZIP file
              path.delete
              logger.info(
                "Removed ZIP file",
                mod_name: installed_mod.mod.name,
                version: installed_mod.version.to_s,
                path: path.to_s
              )
            elsif installed_mod.form == Factorix::InstalledMOD::DIRECTORY_FORM
              # Remove directory
              path.rmtree
              logger.info(
                "Removed directory",
                mod_name: installed_mod.mod.name,
                version: installed_mod.version.to_s,
                path: path.to_s
              )
            end
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
