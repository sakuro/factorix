# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      module MOD
        # Update installed MODs to their latest versions
        class Update < Base
          include Confirmable

          require_game_stopped!

          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Import[:portal, :logger, :runtime]

          desc "Update MODs to their latest versions"

          example [
            "                   # Update all installed MODs",
            "some-mod           # Update specific MOD",
            "mod-a mod-b        # Update multiple MODs",
            "-j 8 mod-a mod-b   # Use 8 parallel downloads"
          ]

          argument :mod_names, type: :array, required: false, desc: "MOD names to update (all if not specified)"
          option :jobs, type: :integer, aliases: ["-j"], default: 4, desc: "Number of parallel downloads"

          # Execute the update command
          #
          # @param mod_names [Array<String>] MOD names to update
          # @param jobs [Integer] Number of parallel downloads
          # @return [void]
          def call(mod_names: [], jobs: 4, **)
            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Scanning MODs", output: $stderr)
            handler = Progress::ScanHandler.new(presenter)
            installed_mods = InstalledMOD.all(handler:)
            mod_list = MODList.load(runtime.mod_list_path)

            # Determine target MODs
            target_mods = if mod_names.empty?
                            # All installed MODs except base and expansion
                            mods = installed_mods.map(&:mod)
                            mods.uniq!
                            mods.reject! {|mod| mod.base? || mod.expansion? }
                            mods
                          else
                            # Specified MODs only
                            mod_names.map {|name| validate_and_get_mod(name) }
                          end

            if target_mods.empty?
              say "No MOD(s) to update", prefix: :info
              return
            end

            # Find MODs with available updates
            update_targets = find_update_targets(target_mods, installed_mods, jobs)

            if update_targets.empty?
              say "All MOD(s) are up to date", prefix: :info
              return
            end

            # Show plan
            show_plan(update_targets)
            return unless confirm?("Do you want to update these MODs?")

            # Execute updates
            execute_updates(update_targets, mod_list, jobs)

            # Save mod-list.json
            mod_list.save(runtime.mod_list_path)
            say "Updated #{update_targets.size} MOD(s)", prefix: :success
            say "Saved mod-list.json", prefix: :success
          end

          # Validate MOD name and return MOD object
          #
          # @param mod_name [String] MOD name
          # @return [MOD] MOD object
          # @raise [Error] if MOD is base or expansion
          private def validate_and_get_mod(mod_name)
            mod = Factorix::MOD[name: mod_name]

            raise Error, "Cannot update base MOD" if mod.base?
            raise Error, "Cannot update expansion MOD: #{mod}" if mod.expansion?

            mod
          end

          # Find MODs that have available updates
          #
          # @param target_mods [Array<MOD>] Target MODs to check
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @param jobs [Integer] Number of parallel jobs
          # @return [Array<Hash>] Update targets with current and latest versions
          private def find_update_targets(target_mods, installed_mods, jobs)
            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Checking for updates", output: $stderr)
            presenter.start(total: target_mods.size)

            pool = Concurrent::FixedThreadPool.new(jobs)

            futures = target_mods.map {|mod|
              Concurrent::Future.execute(executor: pool) do
                result = check_mod_for_update(mod, installed_mods)
                presenter.update
                result
              end
            }

            results = futures.filter_map(&:value!)
            presenter.finish
            results
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end

          # Check a single MOD for available updates
          #
          # @param mod [MOD] MOD to check
          # @param installed_mods [Array<InstalledMOD>] All installed MODs
          # @return [Hash, nil] Update target info or nil if no update available
          private def check_mod_for_update(mod, installed_mods)
            # Find current installed version
            current_versions = installed_mods.select {|im| im.mod == mod }
            return nil if current_versions.empty?

            current_version = current_versions.map(&:version).max

            # Fetch latest version from portal
            mod_info = portal.get_mod_full(mod.name)
            latest_release = mod_info.releases.max_by(&:released_at)

            return nil unless latest_release
            return nil if latest_release.version <= current_version

            {
              mod:,
              mod_info:,
              current_version:,
              latest_release:,
              output_path: runtime.mod_dir / latest_release.file_name
            }
          rescue MODNotOnPortalError
            logger.debug("MOD not found on portal", mod: mod.name)
            nil
          end

          # Show the update plan
          #
          # @param targets [Array<Hash>] Update targets
          # @return [void]
          private def show_plan(targets)
            say "Planning to update #{targets.size} MOD(s):", prefix: :info
            targets.each do |target|
              say "  - #{target[:mod]}: #{target[:current_version]} -> #{target[:latest_release].version}"
            end
          end

          # Execute the updates
          #
          # @param targets [Array<Hash>] Update targets
          # @param mod_list [MODList] MOD list
          # @param jobs [Integer] Number of parallel jobs
          # @return [void]
          private def execute_updates(targets, mod_list, jobs)
            # Download new versions
            download_mods(targets, jobs)

            # Update mod-list.json (remove version pinning)
            targets.each do |target|
              mod = target[:mod]

              if mod_list.exist?(mod)
                # Remove version pinning if present
                current_enabled = mod_list.enabled?(mod)
                mod_list.remove(mod)
                mod_list.add(mod, enabled: current_enabled)
                say "Updated #{mod} to #{target[:latest_release].version}", prefix: :success
              else
                mod_list.add(mod, enabled: true)
                say "Added #{mod} to mod-list.json", prefix: :success
              end
            end
          end

          # Download MODs in parallel
          #
          # @param targets [Array<Hash>] Update targets
          # @param jobs [Integer] Number of parallel jobs
          # @return [void]
          private def download_mods(targets, jobs)
            multi_presenter = Progress::MultiPresenter.new(title: "\u{1F4E5}\u{FE0E} Downloads")

            pool = Concurrent::FixedThreadPool.new(jobs)

            futures = targets.map {|target|
              Concurrent::Future.execute(executor: pool) do
                thread_portal = Application[:portal]
                thread_downloader = thread_portal.mod_download_api.downloader

                presenter = multi_presenter.register(
                  target[:mod].name,
                  title: target[:latest_release].file_name
                )
                handler = Progress::DownloadHandler.new(presenter)

                thread_downloader.subscribe(handler)
                thread_portal.download_mod(target[:latest_release], target[:output_path])
                thread_downloader.unsubscribe(handler)
              end
            }

            futures.each(&:wait!)
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end
        end
      end
    end
  end
end
