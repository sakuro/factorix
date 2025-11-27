# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # List installed MODs
        class List < Base
          # @!parse
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          #   # @return [Factorix::API::MODPortalAPI]
          #   attr_reader :mod_portal_api
          include Import[:logger, :runtime, :mod_portal_api]

          desc "List installed MOD(s)"

          example [
            "             # List all installed MOD(s)",
            "--enabled    # List only enabled MOD(s)",
            "--outdated   # List MOD(s) with available updates",
            "--json       # Output in JSON format"
          ]

          option :enabled, type: :flag, default: false, desc: "Show only enabled MOD(s)"
          option :disabled, type: :flag, default: false, desc: "Show only disabled MOD(s)"
          option :errors, type: :flag, default: false, desc: "Show only MOD(s) with dependency errors"
          option :outdated, type: :flag, default: false, desc: "Show only MOD(s) with available updates"
          option :json, type: :flag, default: false, desc: "Output in JSON format"

          # MOD information for display
          MODInfo = Data.define(:name, :version, :enabled, :error, :latest_version)

          # @!parse
          #   class MODInfo
          #     # @return [String] MOD name
          #     attr_reader :name
          #     # @return [Types::MODVersion] MOD version
          #     attr_reader :version
          #     # @return [Boolean] enabled status
          #     attr_reader :enabled
          #     # @return [String, nil] error message if any
          #     attr_reader :error
          #     # @return [Types::MODVersion, nil] latest version available on portal
          #     attr_reader :latest_version
          #   end
          class MODInfo
            # Get the display status string
            #
            # @return [String] "error", "enabled", or "disabled"
            def status
              return "error" if error

              enabled ? "enabled" : "disabled"
            end

            # Check if a newer version is available
            #
            # @return [Boolean] true if latest_version is newer than current version
            def outdated?
              return false unless latest_version

              latest_version > version
            end
          end

          # Execute the list command
          #
          # @param enabled [Boolean] show only enabled MODs
          # @param disabled [Boolean] show only disabled MODs
          # @param errors [Boolean] show only MODs with dependency errors
          # @param outdated [Boolean] show only MODs with available updates
          # @param json [Boolean] output in JSON format
          # @return [void]
          def call(enabled:, disabled:, errors:, outdated:, json:, **)
            validate_filter_options!(enabled:, disabled:, errors:, outdated:)

            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Scanning MOD(s)", output: $stderr)
            handler = Progress::ScanHandler.new(presenter)
            installed_mods = InstalledMOD.all(handler:)
            mod_list = MODList.load(runtime.mod_list_path)

            # Build list of MOD info
            mod_infos = build_mod_infos(installed_mods, mod_list)
            total_count = mod_infos.size

            # Apply filters
            mod_infos = apply_filters(mod_infos, enabled:, disabled:, errors:, outdated:)

            # Sort
            mod_infos = sort_mods(mod_infos)

            # Determine active filter for summary
            active_filter = if enabled then :enabled
                            elsif disabled then :disabled
                            elsif errors then :errors
                            elsif outdated then :outdated
                            end

            # Output
            if json
              output_json(mod_infos)
            else
              output_table(mod_infos, show_latest: outdated, active_filter:, total_count:)
            end
          end

          # Validate that conflicting filter options are not specified together
          #
          # @param enabled [Boolean] show only enabled MODs
          # @param disabled [Boolean] show only disabled MODs
          # @param errors [Boolean] show only MODs with dependency errors
          # @param outdated [Boolean] show only MODs with available updates
          # @return [void]
          # @raise [ArgumentError] if conflicting options are specified
          private def validate_filter_options!(enabled:, disabled:, errors:, outdated:)
            filters = []
            filters << "--enabled" if enabled
            filters << "--disabled" if disabled
            filters << "--errors" if errors
            filters << "--outdated" if outdated

            return if filters.size <= 1

            raise ArgumentError, "Cannot combine #{filters.join(", ")} options"
          end

          # Build list of MOD info from installed MODs
          #
          # @param installed_mods [Array<InstalledMOD>] installed MODs
          # @param mod_list [MODList] MOD list with enabled status
          # @return [Array<MODInfo>] MOD info list
          private def build_mod_infos(installed_mods, mod_list)
            # Group installed MODs by name to handle multiple versions
            grouped = installed_mods.group_by(&:mod)

            grouped.map {|mod, versions|
              # Determine which version to display (enabled version or latest if disabled)
              display_version = determine_display_version(mod, versions, mod_list)
              enabled = mod_list.exist?(mod) && mod_list.enabled?(mod)

              # Check for dependency errors (placeholder - would need dependency graph)
              error = nil

              MODInfo.new(
                name: mod.name,
                version: display_version,
                enabled:,
                error:,
                latest_version: nil
              )
            }
          end

          # Determine which version of a MOD to display
          #
          # Returns the specified version from mod-list.json if present,
          # otherwise returns the latest installed version.
          #
          # @param mod [MOD] the MOD
          # @param versions [Array<InstalledMOD>] installed versions of the MOD
          # @param mod_list [MODList] MOD list with enabled status and version
          # @return [Types::MODVersion] the version to display
          private def determine_display_version(mod, versions, mod_list)
            # If mod-list.json specifies a version, use that
            if mod_list.exist?(mod)
              specified_version = mod_list.version(mod)
              return specified_version if specified_version
            end

            # Otherwise, use the latest installed version
            versions.map(&:version).max
          end

          # Apply filters to MOD info list
          #
          # @param mod_infos [Array<MODInfo>] MOD info list
          # @param enabled [Boolean] show only enabled MODs
          # @param disabled [Boolean] show only disabled MODs
          # @param errors [Boolean] show only MODs with dependency errors
          # @param outdated [Boolean] show only MODs with available updates
          # @return [Array<MODInfo>] filtered MOD info list
          private def apply_filters(mod_infos, enabled:, disabled:, errors:, outdated:)
            if enabled
              mod_infos = mod_infos.select(&:enabled)
            elsif disabled
              mod_infos = mod_infos.reject(&:enabled)
            elsif errors
              mod_infos = mod_infos.select(&:error)
            elsif outdated
              mod_infos = fetch_latest_versions(mod_infos)
              mod_infos = mod_infos.select(&:outdated?)
            end

            mod_infos
          end

          # Default number of parallel jobs for fetching latest versions
          DEFAULT_JOBS = 4
          private_constant :DEFAULT_JOBS

          # Fetch latest versions from portal for outdated check
          #
          # @param mod_infos [Array<MODInfo>] MOD info list
          # @return [Array<MODInfo>] MOD info list with latest versions
          private def fetch_latest_versions(mod_infos)
            # Separate base/expansion from regular MODs
            base_and_expansions, regular_mods = mod_infos.partition {|info|
              mod = Factorix::MOD[name: info.name]
              mod.base? || mod.expansion?
            }

            # Only show progress for MOD(s) that need API calls
            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Checking for updates", output: $stderr)
            presenter.start(total: regular_mods.size)

            pool = Concurrent::FixedThreadPool.new(DEFAULT_JOBS)

            futures = regular_mods.map {|info|
              Concurrent::Future.execute(executor: pool) do
                result = fetch_latest_version_for_mod(info)
                presenter.update
                result
              end
            }

            results = futures.map(&:value!)
            presenter.finish

            # Combine base/expansion (unchanged) with fetched results
            base_and_expansions + results
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end

          # Fetch latest version for a single MOD
          #
          # @param info [MODInfo] MOD info
          # @return [MODInfo] MOD info with latest version
          private def fetch_latest_version_for_mod(info)
            portal_info = mod_portal_api.get_mod(info.name)
            latest = portal_info[:releases]&.map {|r| Types::MODVersion.from_string(r[:version]) }&.max
            MODInfo.new(
              name: info.name,
              version: info.version,
              enabled: info.enabled,
              error: info.error,
              latest_version: latest
            )
          rescue MODNotOnPortalError
            logger.debug("MOD not found on portal", mod: info.name)
            info
          end

          # Sort MODs: base -> expansion (alphabetically) -> others (alphabetically)
          #
          # @param mod_infos [Array<MODInfo>] MOD info list
          # @return [Array<MODInfo>] sorted MOD info list
          private def sort_mods(mod_infos)
            mod_infos.sort_by do |info|
              mod = Factorix::MOD[name: info.name]
              if mod.base?
                [0, info.name]
              elsif mod.expansion?
                [1, info.name]
              else
                [2, info.name]
              end
            end
          end

          # Output MOD list in table format
          #
          # @param mod_infos [Array<MODInfo>] MOD info list
          # @param show_latest [Boolean] show LATEST column for outdated MODs
          # @param active_filter [Symbol, nil] active filter (:enabled, :disabled, :errors, :outdated, or nil)
          # @param total_count [Integer] total MOD count before filtering
          # @return [void]
          private def output_table(mod_infos, show_latest: false, active_filter: nil, total_count: 0)
            if mod_infos.empty?
              message = active_filter ? "No MOD(s) match the specified criteria" : "No MOD(s) found"
              say message, prefix: :info
              return
            end

            # Calculate column widths
            name_width = [mod_infos.map {|m| m.name.length }.max, 4].max
            version_width = [mod_infos.map {|m| m.version.to_s.length }.max, 7].max

            if show_latest
              latest_width = [mod_infos.map {|m| m.latest_version&.to_s&.length || 0 }.max, 6].max

              # Header with LATEST column
              puts "%-#{name_width}s  %-#{version_width}s  %-#{latest_width}s  %s" % %w[NAME VERSION LATEST STATUS]

              # Rows with LATEST column
              mod_infos.each do |info|
                puts "%-#{name_width}s  %-#{version_width}s  %-#{latest_width}s  %s" % [info.name, info.version, info.latest_version, info.status]
              end
            else
              # Header
              puts "%-#{name_width}s  %-#{version_width}s  %s" % %w[NAME VERSION STATUS]

              # Rows
              mod_infos.each do |info|
                puts "%-#{name_width}s  %-#{version_width}s  %s" % [info.name, info.version, info.status]
              end
            end

            say format_summary(mod_infos.size, active_filter, total_count), prefix: :info
          end

          # Format summary message based on active filter
          #
          # @param count [Integer] filtered MOD count
          # @param active_filter [Symbol, nil] active filter
          # @param total_count [Integer] total MOD count
          # @return [String] formatted summary message
          private def format_summary(count, active_filter, total_count)
            case active_filter
            when :enabled
              "Summary: #{count} enabled MOD(s), #{total_count} total MOD(s)"
            when :disabled
              "Summary: #{count} disabled MOD(s), #{total_count} total MOD(s)"
            when :errors
              "Summary: #{count} MOD(s) with errors, #{total_count} total MOD(s)"
            when :outdated
              "Summary: #{count} outdated MOD(s), #{total_count} total MOD(s)"
            else
              "Summary: #{count} MOD(s)"
            end
          end

          # Output MOD list in JSON format
          #
          # @param mod_infos [Array<MODInfo>] MOD info list
          # @return [void]
          private def output_json(mod_infos)
            data = mod_infos.map {|info|
              {
                name: info.name,
                version: info.version.to_s,
                enabled: info.enabled,
                error: info.error
              }.tap do |h|
                h[:latest_version] = info.latest_version.to_s if info.latest_version
              end
            }

            say JSON.pretty_generate(data)
          end
        end
      end
    end
  end
end
