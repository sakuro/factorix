# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      module MOD
        # Sync MOD states and startup settings from a save file
        class Sync < Base
          include Confirmable
          include DependencyGraphSupport
          include DownloadSupport

          require_game_stopped!

          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Import[:portal, :logger, :runtime]

          desc "Sync MOD states and startup settings from a save file"

          example [
            "save.zip           # Sync MOD(s) from save file",
            "-j 8 save.zip      # Use 8 parallel downloads"
          ]

          argument :save_file, type: :string, required: true, desc: "Path to Factorio save file (.zip)"
          option :jobs, type: :integer, aliases: ["-j"], default: 4, desc: "Number of parallel downloads"

          # Execute the sync command
          #
          # @param save_file [String] Path to save file
          # @param jobs [Integer] Number of parallel downloads
          # @return [void]
          def call(save_file:, jobs: 4, **)
            # Load save file
            say "Loading save file: #{save_file}", prefix: :info
            save_data = SaveFile.load(Pathname(save_file))
            say "Loaded save file (version: #{save_data.version}, MOD(s): #{save_data.mods.size})", prefix: :info

            # Load current state
            graph, mod_list, installed_mods = load_current_state

            # Ensure MOD directory exists
            runtime.mod_dir.mkpath unless runtime.mod_dir.exist?

            # Find MODs that need to be installed
            mods_to_install = find_mods_to_install(save_data.mods, installed_mods)

            if mods_to_install.any?
              say "#{mods_to_install.size} MOD(s) need to be installed", prefix: :info

              # Plan installation
              install_targets = plan_installation(mods_to_install, graph, jobs)

              # Show plan
              show_install_plan(install_targets)
              return unless confirm?("Do you want to install these MOD(s)?")

              # Execute installation
              execute_installation(install_targets, jobs)
              say "Installed #{install_targets.size} MOD(s)", prefix: :success
            else
              say "All MOD(s) from save file are already installed", prefix: :info
            end

            # Resolve conflicts: disable existing MODs that conflict with new ones
            resolve_conflicts(mod_list, save_data.mods, graph)

            # Update mod-list.json
            update_mod_list(mod_list, save_data.mods)
            mod_list.save(runtime.mod_list_path)
            say "Updated mod-list.json", prefix: :success

            # Update mod-settings.dat
            update_mod_settings(save_data.startup_settings, save_data.version)
            say "Updated mod-settings.dat", prefix: :success

            say "Sync completed successfully", prefix: :success
          end

          private def find_mods_to_install(save_mods, installed_mods)
            save_mods.reject do |mod_name, _mod_state|
              # Skip base MOD (always installed)
              next true if mod_name == "base"

              # Check if MOD is installed
              mod = Factorix::MOD[name: mod_name]
              installed_mods.any? {|installed| installed.mod == mod }
            end
          end

          # Plan the installation by fetching MOD info and extending the graph
          #
          # @param mods_to_install [Hash<String, MODState>] MODs to install
          # @param graph [Dependency::Graph] Current dependency graph
          # @param jobs [Integer] Number of parallel jobs
          # @return [Array<Hash>] Installation targets with MOD info and releases
          private def plan_installation(mods_to_install, graph, jobs)
            # Create progress presenter for info fetching
            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Fetching MOD info", output: $stderr)

            # Fetch info for MODs to install
            target_infos = fetch_target_mod_info(mods_to_install, jobs, presenter)

            # Add to graph
            target_infos.each do |info|
              graph.add_uninstalled_mod(info[:mod_info], info[:release])
            end

            # Build install targets
            build_install_targets(target_infos, runtime.mod_dir)
          end

          # Fetch MOD information for MODs to install
          #
          # @param mods_to_install [Hash<String, MODState>] MODs to install
          # @param jobs [Integer] Number of parallel jobs
          # @param presenter [Progress::Presenter] Progress presenter
          # @return [Array<Hash>] Array of {mod_name:, mod_info:, release:, version:}
          private def fetch_target_mod_info(mods_to_install, jobs, presenter)
            presenter.start(total: mods_to_install.size)

            pool = Concurrent::FixedThreadPool.new(jobs)

            futures = mods_to_install.map {|mod_name, mod_state|
              Concurrent::Future.execute(executor: pool) do
                result = fetch_single_mod_info(mod_name, mod_state.version)
                presenter.update
                result
              end
            }

            results = futures.map(&:value!)
            results
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end

          # Fetch information for a single MOD
          #
          # @param mod_name [String] MOD name
          # @param version [Types::MODVersion] Target version
          # @return [Hash] {mod_name:, mod_info:, release:, version:}
          private def fetch_single_mod_info(mod_name, version)
            # Fetch full MOD info from portal
            mod_info = portal.get_mod_full(mod_name)

            # Find the specific version release
            release = mod_info.releases.find {|r| r.version == version }

            unless release
              raise Error, "Release not found for #{mod_name}@#{version}"
            end

            {mod_name:, mod_info:, release:, version:}
          end

          # Show the installation plan
          #
          # @param targets [Array<Hash>] Installation targets
          # @return [void]
          private def show_install_plan(targets)
            say "Planning to install #{targets.size} MOD(s):", prefix: :info
            targets.each do |target|
              say "  - #{target[:mod]}@#{target[:release].version}"
            end
          end

          # Execute the installation
          #
          # @param targets [Array<Hash>] Installation targets
          # @param jobs [Integer] Number of parallel jobs
          # @return [void]
          private def execute_installation(targets, jobs)
            # Download all MODs
            download_mods(targets, jobs)
          end

          # Resolve conflicts between save file MODs and existing enabled MODs
          #
          # @param mod_list [MODList] Current MOD list
          # @param save_mods [Hash<String, MODState>] MODs from save file
          # @param graph [Dependency::Graph] Dependency graph
          # @return [void]
          private def resolve_conflicts(mod_list, save_mods, graph)
            # For each MOD in save file that will be enabled
            save_mods.each do |mod_name, mod_state|
              next unless mod_state.enabled?

              mod = Factorix::MOD[name: mod_name]

              # Find incompatible MODs from the graph
              graph.edges_from(mod).each do |edge|
                next unless edge.incompatible?

                conflicting_mod = edge.to_mod

                # If the conflicting MOD is currently enabled, disable it
                next unless mod_list.exist?(conflicting_mod) && mod_list.enabled?(conflicting_mod)

                mod_list.disable(conflicting_mod)
                say "Disabled #{conflicting_mod} (conflicts with #{mod} from save file)", prefix: :warn
                logger.debug("Disabled conflicting MOD", mod_name: conflicting_mod.name, conflicts_with: mod.name)
              end

              # Also check incoming incompatibility edges
              graph.edges_to(mod).each do |edge|
                next unless edge.incompatible?

                conflicting_mod = edge.from_mod

                # If the conflicting MOD is currently enabled, disable it
                next unless mod_list.exist?(conflicting_mod) && mod_list.enabled?(conflicting_mod)

                mod_list.disable(conflicting_mod)
                say "Disabled #{conflicting_mod} (conflicts with #{mod} from save file)", prefix: :warn
                logger.debug("Disabled conflicting MOD", mod_name: conflicting_mod.name, conflicts_with: mod.name)
              end
            end
          end

          # Update mod-list.json with MODs from save file
          #
          # @param mod_list [MODList] Current MOD list
          # @param save_mods [Hash<String, MODState>] MODs from save file
          # @return [void]
          private def update_mod_list(mod_list, save_mods)
            save_mods.each do |mod_name, mod_state|
              mod = Factorix::MOD[name: mod_name]

              # base MOD: don't update version or enabled state
              if mod.base?
                logger.debug("Skipping base MOD (no changes allowed)", mod_name:)
                next
              end

              if mod_list.exist?(mod)
                # expansion MOD: only update enabled state (not version)
                if mod.expansion?
                  if mod_state.enabled? && !mod_list.enabled?(mod)
                    mod_list.enable(mod)
                    logger.debug("Enabled expansion MOD in mod-list.json", mod_name:)
                  elsif !mod_state.enabled? && mod_list.enabled?(mod)
                    mod_list.disable(mod)
                    logger.debug("Disabled expansion MOD in mod-list.json", mod_name:)
                  end
                else
                  # Regular MOD: update both version and enabled state
                  # Remove and re-add to update version
                  mod_list.remove(mod)
                  mod_list.add(mod, enabled: mod_state.enabled?, version: mod_state.version)
                  logger.debug("Updated MOD in mod-list.json", mod_name:, version: mod_state.version&.to_s, enabled: mod_state.enabled?)
                end
              else
                # Add new entry (version from save file)
                mod_list.add(mod, enabled: mod_state.enabled?, version: mod_state.version)
                logger.debug("Added to mod-list.json", mod_name:, version: mod_state.version&.to_s)
              end
            end
          end

          # Update mod-settings.dat with startup settings from save file
          #
          # @param startup_settings [MODSettings::Section] Startup settings from save file
          # @param game_version [Types::GameVersion] Game version from save file
          # @return [void]
          private def update_mod_settings(startup_settings, game_version)
            # Load existing settings or create new
            mod_settings = if runtime.mod_settings_path.exist?
                             MODSettings.load(runtime.mod_settings_path)
                           else
                             # Create new MODSettings with all sections
                             sections = MODSettings::VALID_SECTIONS.to_h {|section_name|
                               [section_name, MODSettings::Section.new(section_name)]
                             }
                             MODSettings.new(game_version, sections)
                           end

            # Merge startup settings from save file
            startup_section = mod_settings["startup"]
            startup_settings.each do |key, value|
              startup_section[key] = value
            end

            # Save updated settings
            mod_settings.save(runtime.mod_settings_path)
          end
        end
      end
    end
  end
end
