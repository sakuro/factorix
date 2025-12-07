# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      module MOD
        # Install MODs from Factorio MOD Portal
        class Install < Base
          confirmable!
          require_game_stopped!
          backup_support!

          include DownloadSupport

          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Import[:portal, :logger, :runtime]

          desc "Install MOD(s) from Factorio MOD Portal (downloads to MOD directory and enables)"

          example [
            "some-mod            # Install latest version",
            "some-mod@1.2.0      # Install specific version",
            "some-mod@latest     # Install latest version explicitly",
            "-j 8 mod-a mod-b    # Use 8 parallel downloads"
          ]

          argument :mod_specs, type: :array, required: true, desc: "MOD specifications (name@version or name@latest or name)"
          option :jobs, type: :integer, aliases: ["-j"], default: 4, desc: "Number of parallel downloads"

          # Execute the install command
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param jobs [Integer] Number of parallel downloads
          # @return [void]
          def call(mod_specs:, jobs: 4, **)
            # Load current state (without validation to allow fixing issues)
            mod_list = MODList.load
            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Scanning MOD(s)", output: $stderr)
            handler = Progress::ScanHandler.new(presenter)
            installed_mods = InstalledMOD.all(handler:)
            graph = Dependency::Graph::Builder.build(installed_mods:, mod_list:)

            raise DirectoryNotFoundError, "MOD directory does not exist: #{runtime.mod_dir}" unless runtime.mod_dir.exist?

            # Plan installation (fetch info, extend graph, validate)
            install_targets = plan_installation(mod_specs, graph, jobs)

            if install_targets.empty?
              say "All specified MOD(s) are already installed and enabled", prefix: :info
              return
            end

            # Show plan
            show_plan(install_targets)
            return unless confirm?("Do you want to proceed?")

            # Execute installation
            execute_installation(install_targets, graph, mod_list, jobs)

            # Save mod-list.json
            backup_if_exists(runtime.mod_list_path)
            mod_list.save

            install_count = install_targets.count {|t| t[:operation] == :install }
            enable_count = install_targets.count {|t| t[:operation] == :enable }

            if install_count > 0
              say "Installed #{install_count} MOD(s)", prefix: :success
            end
            if enable_count > 0
              say "Enabled #{enable_count} disabled dependency MOD(s)", prefix: :success
            end
            say "Saved mod-list.json", prefix: :success
            logger.debug("Saved mod-list.json")
          end

          # Mark disabled dependencies for enabling
          #
          # Recursively traverses required dependencies and marks disabled MODs for enabling.
          #
          # @param graph [Dependency::Graph] The dependency graph
          # @return [void]
          def mark_disabled_dependencies_for_enable(graph)
            # Find all MODs that will be installed or enabled
            mods_to_process = graph.nodes.filter_map {|node| node.mod if node.operation == :install }

            processed = Set.new

            until mods_to_process.empty?
              mod = mods_to_process.shift
              next if processed.include?(mod)

              processed.add(mod)

              graph.edges_from(mod).each do |edge|
                next unless edge.required?

                dep_node = graph.node(edge.to_mod)
                next unless dep_node

                # Skip if already has an operation or is enabled
                next if dep_node.operation
                next if dep_node.enabled?

                # Mark for enabling if installed but disabled
                next unless dep_node.installed?

                graph.set_node_operation(edge.to_mod, :enable)
                mods_to_process << edge.to_mod
              end
            end
          end
          # Plan the installation by fetching MOD info and extending the graph
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param graph [Dependency::Graph] Current dependency graph
          # @param jobs [Integer] Number of parallel jobs
          # @return [Array<Hash>] Installation targets with MOD info and releases
          private def plan_installation(mod_specs, graph, jobs)
            # Create progress presenter for info fetching
            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Fetching MOD info", output: $stderr)

            # Phase 1: Fetch info for target MODs
            target_infos = fetch_target_mod_info(mod_specs, jobs, presenter)

            # Phase 2: Recursively resolve dependencies and extend graph
            all_mod_infos = resolve_dependencies_with_graph(target_infos, graph, jobs, presenter)

            # Phase 3: Mark disabled dependencies for enabling
            mark_disabled_dependencies_for_enable(graph)

            # Phase 4: Validate graph (cycles, conflicts)
            validate_installation_graph(graph)

            # Phase 5: Extract install targets from graph
            extract_install_targets(graph, all_mod_infos)
          end

          # Fetch MOD information for target specifications
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param jobs [Integer] Number of parallel jobs
          # @param presenter [Progress::Presenter] Progress presenter
          # @return [Array<Hash>] Array of {mod_spec:, mod_info:, release:}
          private def fetch_target_mod_info(mod_specs, jobs, presenter)
            presenter.start

            pool = Concurrent::FixedThreadPool.new(jobs)

            futures = mod_specs.map {|mod_spec|
              Concurrent::Future.execute(executor: pool) do
                result = fetch_single_mod_info(mod_spec)
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

          # Fetch information for a single MOD specification
          #
          # @param mod_spec [String] MOD specification (name@version or name)
          # @return [Hash] {mod:, mod_name:, mod_info:, release:, version:}
          private def fetch_single_mod_info(mod_spec)
            parsed = parse_mod_spec(mod_spec)
            mod = parsed[:mod]
            version = parsed[:version]

            mod_info = portal.get_mod_full(mod.name)
            release = find_release(mod_info, version)

            version_display = version == :latest ? "latest" : version.to_s
            raise MODNotOnPortalError, "Release not found for #{mod}@#{version_display}" unless release

            {mod:, mod_name: mod.name, mod_info:, release:, version:}
          end

          # Recursively resolve dependencies and extend the graph
          #
          # @param target_infos [Array<Hash>] Initial target MOD infos
          # @param graph [Dependency::Graph] Graph to extend
          # @param jobs [Integer] Number of parallel jobs
          # @param presenter [Progress::Presenter] Progress presenter
          # @return [Hash<String, Hash>] All MOD infos by name
          private def resolve_dependencies_with_graph(target_infos, graph, jobs, presenter)
            all_mod_infos = {}
            to_process = []

            # Add target MODs to graph and processing queue
            target_infos.each do |info|
              all_mod_infos[info[:mod_name]] = info
              graph.add_uninstalled_mod(info[:mod_info], info[:release])
              to_process << info[:mod_name]
            end

            # Process dependencies recursively
            processed = Set.new

            until to_process.empty?
              # Get next batch of MODs to process
              current_batch = to_process.shift(jobs)
              current_batch.reject! {|mod_name| processed.include?(mod_name) }
              break if current_batch.empty?

              # Find dependencies for current batch
              new_dependencies = []
              current_batch.each do |mod_name|
                processed.add(mod_name)

                node = graph.node(Factorix::MOD[name: mod_name])
                next unless node

                # Find dependencies that aren't in graph yet
                # Only process required dependencies - skip optional, hidden, load_neutral, and incompatible
                graph.edges_from(node.mod).each do |edge|
                  next unless edge.required?

                  dep_mod = edge.to_mod

                  next if graph.node?(dep_mod)

                  # Need to fetch this dependency
                  new_dependencies << {mod: dep_mod, version_requirement: edge.version_requirement, required_by: mod_name}
                end
              end

              # Fetch info for new dependencies
              next if new_dependencies.empty?

              # Increase progress bar total for newly discovered dependencies
              presenter.increase_total(new_dependencies.size)

              fetch_and_add_dependencies(new_dependencies, graph, all_mod_infos, jobs, presenter)

              # Add newly added MODs to processing queue
              new_dependencies.each do |dep|
                to_process << dep[:mod].name unless processed.include?(dep[:mod].name)
              end
            end

            all_mod_infos
          end

          # Fetch and add dependencies to the graph
          #
          # @param dependencies [Array<Hash>] Dependencies to fetch
          # @param graph [Dependency::Graph] Graph to extend
          # @param all_mod_infos [Hash] Accumulator for all MOD infos
          # @param jobs [Integer] Number of parallel jobs
          # @param presenter [Progress::Presenter] Progress presenter
          # @return [void]
          private def fetch_and_add_dependencies(dependencies, graph, all_mod_infos, jobs, presenter)
            pool = Concurrent::FixedThreadPool.new(jobs)

            futures = dependencies.map {|dep|
              Concurrent::Future.execute(executor: pool) do
                mod_info = portal.get_mod_full(dep[:mod].name)
                release = find_compatible_release(mod_info, dep[:version_requirement])

                unless release
                  # Skip dependencies without compatible releases (e.g., all releases have invalid versions)
                  logger.warn("Skipping dependency #{dep[:mod]} (required by #{dep[:required_by]}): No compatible release found")
                  presenter.update
                  next nil
                end

                presenter.update

                {mod_name: dep[:mod].name, mod_info:, release:}
              rescue HTTPClientError => e
                # Skip dependencies that cannot be found (404, etc.)
                logger.warn("Skipping dependency #{dep[:mod]} (required by #{dep[:required_by]}): #{e.message}")
                presenter.update
                nil
              rescue JSON::ParserError
                # Skip dependencies with invalid/empty API responses
                logger.warn("Skipping dependency #{dep[:mod]} (required by #{dep[:required_by]}): Invalid API response")
                presenter.update
                nil
              end
            }

            results = futures.filter_map(&:value!)

            # Add to graph
            results.each do |result|
              all_mod_infos[result[:mod_name]] = result
              graph.add_uninstalled_mod(result[:mod_info], result[:release])
            end
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end

          # Validate the installation graph
          #
          # @param graph [Dependency::Graph] Graph to validate
          # @return [void]
          # @raise [CircularDependencyError] if circular dependency detected
          # @raise [MODConflictError] if MOD conflicts with enabled MOD

          private def validate_installation_graph(graph)
            # Check for cycles
            if graph.cyclic?
              # Get strongly connected components (cycles)
              cycles = graph.strongly_connected_components.select {|component| component.size > 1 }

              logger.error("Circular dependency detected. Cycles found:")
              cycles.each do |cycle|
                logger.error("  Cycle: #{cycle.join(" <-> ")}")
              end

              raise CircularDependencyError, "Circular dependency detected in MOD(s) to install"
            end

            graph.nodes.each do |node|
              next unless node.operation == :install

              graph.edges_from(node.mod).each do |edge|
                next unless edge.incompatible?

                target_node = graph.node(edge.to_mod)
                if target_node&.enabled?
                  raise MODConflictError,
                    "Cannot install #{node.mod}: it conflicts with enabled MOD #{edge.to_mod}"
                end
              end
            end
          end

          # Extract install targets from the graph
          #
          # @param graph [Dependency::Graph] Graph with install operations
          # @param all_mod_infos [Hash] All MOD infos by name
          # @return [Array<Hash>] Install targets
          private def extract_install_targets(graph, all_mod_infos)
            # Filter MODs marked for installation or enabling
            graph.nodes.filter_map {|node|
              if node.operation == :install
                info = all_mod_infos[node.mod.name]
                unless info
                  logger.warn("No info found for #{node.mod}, skipping")
                  next
                end

                {
                  mod: node.mod,
                  operation: :install,
                  mod_info: info[:mod_info],
                  release: info[:release],
                  output_path: runtime.mod_dir / info[:release].file_name,
                  category: info[:mod_info].category
                }
              elsif node.operation == :enable
                {
                  mod: node.mod,
                  operation: :enable
                }
              end
            }
          end

          # Show the installation plan
          #
          # @param targets [Array<Hash>] Installation targets
          # @return [void]
          private def show_plan(targets)
            install_targets = targets.select {|t| t[:operation] == :install }
            enable_targets = targets.select {|t| t[:operation] == :enable }

            if install_targets.any?
              say "Planning to install #{install_targets.size} MOD(s):", prefix: :info
              install_targets.each do |target|
                say "  - #{target[:mod]}@#{target[:release].version}"
              end
            end

            return if enable_targets.none?

            say "Planning to enable #{enable_targets.size} disabled dependency MOD(s):", prefix: :info
            enable_targets.each do |target|
              say "  - #{target[:mod]}"
            end
          end

          # Execute the installation
          #
          # @param targets [Array<Hash>] Installation targets
          # @param graph [Dependency::Graph] Dependency graph
          # @param mod_list [MODList] MOD list
          # @param jobs [Integer] Number of parallel jobs
          # @return [void]
          private def execute_installation(targets, _graph, mod_list, jobs)
            # Download MODs that need to be installed (not just enabled)
            install_targets = targets.select {|t| t[:operation] == :install }
            download_mods(install_targets, jobs) unless install_targets.empty?

            # Add/enable all MODs in mod-list.json
            targets.each do |target|
              mod = target[:mod]

              case target[:operation]
              when :install
                if mod_list.exist?(mod)
                  unless mod_list.enabled?(mod)
                    mod_list.enable(mod)
                    say "Enabled #{mod} in mod-list.json", prefix: :success
                    logger.debug("Enabled in mod-list.json", mod_name: mod.name)
                  end
                else
                  mod_list.add(mod, enabled: true)
                  say "Added #{mod} to mod-list.json", prefix: :success
                  logger.debug("Added to mod-list.json", mod_name: mod.name)
                end
              when :enable
                mod_list.enable(mod)
                say "Enabled dependency #{mod} in mod-list.json", prefix: :success
                logger.debug("Enabled dependency in mod-list.json", mod_name: mod.name)
              else
                logger.warn("Unknown operation #{target[:operation]} for #{mod}")
              end
            end
          end
        end
      end
    end
  end
end
