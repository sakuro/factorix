# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      module MOD
        # Sync MOD states and startup settings from a save file
        class Sync < Base
          confirmable!
          require_game_stopped!
          backup_support!

          include DownloadSupport
          include PortalSupport

          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Import[:logger, :runtime]

          desc "Sync MOD states and startup settings from a save file"

          example [
            "save.zip                 # Sync MOD(s) from save file",
            "-j 8 save.zip            # Use 8 parallel downloads",
            "--keep-unlisted save.zip # Keep MOD(s) not in save file enabled"
          ]

          argument :save_file, required: true, desc: "Path to Factorio save file (.zip)"
          option :jobs, aliases: ["-j"], default: "4", desc: "Number of parallel downloads"
          option :keep_unlisted, type: :flag, default: false, desc: "Keep MOD(s) not listed in save file enabled"

          # Execute the sync command
          #
          # @param save_file [String] Path to save file
          # @param jobs [Integer] Number of parallel downloads
          # @param keep_unlisted [Boolean] Whether to keep unlisted MODs enabled
          # @return [void]
          def call(save_file:, jobs: "4", keep_unlisted: false, **)
            jobs = Integer(jobs)
            say "Loading save file: #{save_file}", prefix: :info
            save_data = SaveFile.load(Pathname(save_file))
            say "Loaded save file (version: #{save_data.version}, MOD(s): #{save_data.mods.size})", prefix: :info

            mod_list = MODList.load
            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Scanning MOD(s)", output: err)
            handler = Progress::ScanHandler.new(presenter)
            installed_mods = InstalledMOD.all(handler:)
            graph = Dependency::Graph::Builder.build(installed_mods:, mod_list:)

            raise DirectoryNotFoundError, "MOD directory does not exist: #{runtime.mod_dir}" unless runtime.mod_dir.exist?

            # Plan phase (no side effects)
            mods_to_install = find_mods_to_install(save_data.mods, installed_mods)
            install_targets = mods_to_install.any? ? plan_installation(mods_to_install, graph, jobs) : []
            conflict_mods = find_conflict_mods(mod_list, save_data.mods, graph)
            changes = plan_mod_list_changes(mod_list, save_data.mods)
            unlisted_mods = keep_unlisted ? [] : find_unlisted_mods(mod_list, save_data.mods, conflict_mods)

            # Show combined plan and ask once
            show_sync_plan(install_targets, conflict_mods, changes, unlisted_mods)

            return if needs_confirmation?(install_targets, conflict_mods, changes, unlisted_mods) &&
                      !confirm?("Do you want to apply these changes?")

            # Execute phase
            if install_targets.any?
              execute_installation(install_targets, jobs)
              say "Installed #{install_targets.size} MOD(s)", prefix: :success
            end

            apply_mod_list_changes(mod_list, conflict_mods, changes, unlisted_mods)
            backup_if_exists(runtime.mod_list_path)
            mod_list.save
            say "Updated mod-list.json", prefix: :success

            update_mod_settings(save_data.startup_settings, save_data.version)
            say "Updated mod-settings.dat", prefix: :success

            say "Sync completed successfully", prefix: :success
          end

          private def find_mods_to_install(save_mods, installed_mods)
            save_mods.reject do |mod_name, _mod_state|
              next true if mod_name == "base"

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
            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Fetching MOD info", output: err)
            target_infos = fetch_target_mod_info(mods_to_install, jobs, presenter)

            target_infos.each do |info|
              graph.add_uninstalled_mod(info[:mod_info], info[:release])
            end

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
          # @param version [MODVersion] Target version
          # @return [Hash] {mod_name:, mod_info:, release:, version:}
          private def fetch_single_mod_info(mod_name, version)
            mod_info = portal.get_mod_full(mod_name)
            release = mod_info.releases.find {|r| r.version == version }

            unless release
              raise MODNotOnPortalError, "Release not found for #{mod_name}@#{version}"
            end

            {mod_name:, mod_info:, release:, version:}
          end

          # Execute the installation
          #
          # @param targets [Array<Hash>] Installation targets
          # @param jobs [Integer] Number of parallel jobs
          # @return [void]
          private def execute_installation(targets, jobs)
            download_mods(targets, jobs)
          end

          # Find MODs that conflict with enabled MODs from the save file
          #
          # @param mod_list [MODList] Current MOD list
          # @param save_mods [Hash<String, MODState>] MODs from save file
          # @param graph [Dependency::Graph] Dependency graph
          # @return [Array<Hash>] Conflict entries: {mod:, conflicts_with:}
          private def find_conflict_mods(mod_list, save_mods, graph)
            conflicts = []
            seen = Set.new

            save_mods.each do |mod_name, mod_state|
              next unless mod_state.enabled?

              save_mod = Factorix::MOD[name: mod_name]

              graph.edges_from(save_mod).each do |edge|
                next unless edge.incompatible?

                conflicting_mod = edge.to_mod
                next unless mod_list.exist?(conflicting_mod) && mod_list.enabled?(conflicting_mod)
                next unless seen.add?(conflicting_mod)

                conflicts << {mod: conflicting_mod, conflicts_with: save_mod}
              end

              graph.edges_to(save_mod).each do |edge|
                next unless edge.incompatible?

                conflicting_mod = edge.from_mod
                next unless mod_list.exist?(conflicting_mod) && mod_list.enabled?(conflicting_mod)
                next unless seen.add?(conflicting_mod)

                conflicts << {mod: conflicting_mod, conflicts_with: save_mod}
              end
            end

            conflicts
          end

          # Compute changes needed to bring mod-list.json in sync with save file
          #
          # @param mod_list [MODList] Current MOD list
          # @param save_mods [Hash<String, MODState>] MODs from save file
          # @return [Array<Hash>] Change entries: {mod:, action:, ...}
          private def plan_mod_list_changes(mod_list, save_mods)
            changes = []

            save_mods.each do |mod_name, mod_state|
              mod = Factorix::MOD[name: mod_name]
              next if mod.base?

              if mod_list.exist?(mod)
                changes.concat(plan_existing_mod_changes(mod_list, mod, mod_state))
              else
                # Not in list: add it (silently if disabled)
                changes << {mod:, action: :add, to_enabled: mod_state.enabled?, to_version: mod_state.version}
              end
            end

            changes
          end

          # Plan changes for a single MOD that already exists in mod-list.json
          #
          # @param mod_list [MODList] Current MOD list
          # @param mod [MOD] The MOD to plan changes for
          # @param mod_state [MODState] MOD state from save file
          # @return [Array<Hash>] Change entries for this MOD
          private def plan_existing_mod_changes(mod_list, mod, mod_state)
            current_enabled = mod_list.enabled?(mod)
            return plan_expansion_mod_changes(mod, mod_state, current_enabled) if mod.expansion?

            current_version = mod_list.version(mod)
            to_enabled = mod_state.enabled?
            to_version = mod_state.version
            enabled_changed = current_enabled != to_enabled
            version_changed = current_version != to_version

            if enabled_changed
              action = to_enabled ? :enable : :disable
              [{mod:, action:, from_version: current_version, to_version:, from_enabled: current_enabled}]
            elsif version_changed
              [{mod:, action: :update, from_version: current_version, to_version:, from_enabled: current_enabled}]
            else
              []
            end
          end

          # Plan enable/disable changes for an expansion MOD
          #
          # @param mod [MOD] The expansion MOD
          # @param mod_state [MODState] MOD state from save file
          # @param current_enabled [Boolean] Current enabled state in mod-list.json
          # @return [Array<Hash>] Change entries (0 or 1 element)
          private def plan_expansion_mod_changes(mod, mod_state, current_enabled)
            if mod_state.enabled? && !current_enabled
              [{mod:, action: :enable}]
            elsif !mod_state.enabled? && current_enabled
              [{mod:, action: :disable}]
            else
              []
            end
          end

          # Find enabled MODs not listed in the save file (excluding conflict MODs)
          #
          # @param mod_list [MODList] Current MOD list
          # @param save_mods [Hash<String, MODState>] MODs from save file
          # @param conflict_mods [Array<Hash>] Already-planned conflict disables
          # @return [Array<MOD>] MODs to disable
          private def find_unlisted_mods(mod_list, save_mods, conflict_mods)
            conflict_mod_set = Set.new(conflict_mods.map {|c| c[:mod] })

            mod_list.each_mod.select do |mod|
              !mod.base? &&
                mod_list.enabled?(mod) &&
                !save_mods.key?(mod.name) &&
                !conflict_mod_set.include?(mod)
            end
          end

          # Show the combined sync plan
          #
          # @param install_targets [Array<Hash>] MODs to install
          # @param conflict_mods [Array<Hash>] MODs to disable due to conflicts
          # @param changes [Array<Hash>] MOD list changes from save file
          # @param unlisted_mods [Array<MOD>] MODs to disable as unlisted
          # @return [void]
          private def show_sync_plan(install_targets, conflict_mods, changes, unlisted_mods)
            unless needs_confirmation?(install_targets, conflict_mods, changes, unlisted_mods)
              say "Nothing to change", prefix: :info
              return
            end

            say "Planning to sync MOD(s):", prefix: :info

            if install_targets.any?
              say "  Install:"
              install_targets.each {|t| say "    - #{t[:mod]}@#{t[:release].version}" }
            end

            enable_changes = changes.select {|c| c[:action] == :enable }
            if enable_changes.any?
              say "  Enable:"
              enable_changes.each {|c| say "    - #{c[:mod]}" }
            end

            disable_changes = changes.select {|c| c[:action] == :disable }
            all_disables = conflict_mods.map {|c| {mod: c[:mod], reason: "(conflicts with #{c[:conflicts_with]})"} } +
                           disable_changes.map {|c| {mod: c[:mod], reason: "(disabled in save file)"} } +
                           unlisted_mods.map {|m| {mod: m, reason: "(not listed in save file)"} }
            if all_disables.any?
              say "  Disable:"
              all_disables.each {|d| say "    - #{d[:mod]} #{d[:reason]}" }
            end

            update_changes = changes.select {|c| c[:action] == :update }
            return if update_changes.none?

            say "  Update:"
            update_changes.each {|c| say "    - #{c[:mod]} (#{c[:from_version]} \u2192 #{c[:to_version]})" }
          end

          # Apply all mod-list.json changes
          #
          # @param mod_list [MODList] MOD list to modify
          # @param conflict_mods [Array<Hash>] Conflict entries to disable
          # @param changes [Array<Hash>] MOD list changes
          # @param unlisted_mods [Array<MOD>] Unlisted MODs to disable
          # @return [void]
          private def apply_mod_list_changes(mod_list, conflict_mods, changes, unlisted_mods)
            conflict_mods.each do |conflict|
              mod_list.disable(conflict[:mod])
              logger.debug("Disabled conflicting MOD", mod_name: conflict[:mod].name, conflicts_with: conflict[:conflicts_with].name)
            end

            changes.each {|change| apply_single_change(mod_list, change) }

            unlisted_mods.each do |mod|
              mod_list.disable(mod)
              logger.debug("Disabled unlisted MOD", mod_name: mod.name)
            end
          end

          # Apply a single change entry to mod-list.json
          #
          # @param mod_list [MODList] MOD list to modify
          # @param change [Hash] Change entry from plan_mod_list_changes
          # @return [void]
          private def apply_single_change(mod_list, change)
            mod = change[:mod]
            case change[:action]
            when :enable
              if mod_list.exist?(mod)
                if mod.expansion?
                  mod_list.enable(mod)
                else
                  mod_list.remove(mod)
                  mod_list.add(mod, enabled: true, version: change[:to_version])
                end
              else
                mod_list.add(mod, enabled: true, version: change[:to_version])
              end
              logger.debug("Enabled MOD in mod-list.json", mod_name: mod.name)
            when :disable
              if mod_list.exist?(mod)
                if mod.expansion?
                  mod_list.disable(mod)
                else
                  mod_list.remove(mod)
                  mod_list.add(mod, enabled: false, version: change[:to_version])
                end
              else
                mod_list.add(mod, enabled: false, version: change[:to_version])
              end
              logger.debug("Disabled MOD in mod-list.json", mod_name: mod.name)
            when :update
              mod_list.remove(mod)
              mod_list.add(mod, enabled: change[:from_enabled], version: change[:to_version])
              logger.debug("Updated MOD in mod-list.json", mod_name: mod.name, version: change[:to_version]&.to_s)
            when :add
              mod_list.add(mod, enabled: change[:to_enabled], version: change[:to_version])
              logger.debug("Added MOD to mod-list.json", mod_name: mod.name, version: change[:to_version]&.to_s, enabled: change[:to_enabled])
            else
              raise ArgumentError, "Unexpected change action: #{change[:action]}"
            end
          end

          # Update mod-settings.dat with startup settings from save file
          #
          # @param startup_settings [MODSettings::Section] Startup settings from save file
          # @param game_version [GameVersion] Game version from save file
          # @return [void]
          private def update_mod_settings(startup_settings, game_version)
            mod_settings = if runtime.mod_settings_path.exist?
                             MODSettings.load(runtime.mod_settings_path)
                           else
                             sections = MODSettings::VALID_SECTIONS.to_h {|section_name|
                               [section_name, MODSettings::Section.new(section_name)]
                             }
                             MODSettings.new(game_version, sections)
                           end

            startup_section = mod_settings["startup"]
            startup_settings.each do |key, value|
              startup_section[key] = value
            end

            backup_if_exists(runtime.mod_settings_path)
            mod_settings.save(runtime.mod_settings_path)
          end

          # Check whether user-visible changes exist that require confirmation
          #
          # @param install_targets [Array<Hash>] MODs to install
          # @param conflict_mods [Array<Hash>] MODs to disable due to conflicts
          # @param changes [Array<Hash>] MOD list changes
          # @param unlisted_mods [Array<MOD>] MODs to disable as unlisted
          # @return [Boolean]
          private def needs_confirmation?(install_targets, conflict_mods, changes, unlisted_mods)
            install_targets.any? ||
              conflict_mods.any? ||
              changes.any? {|c| c[:action] != :add || c[:to_enabled] } ||
              unlisted_mods.any?
          end
        end
      end
    end
  end
end
