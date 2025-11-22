# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      module MOD
        # Install MODs from Factorio MOD Portal
        class Install < Base
          include Confirmable
          include DependencyGraphSupport

          require_game_stopped!

          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Factorix::Runtime]
          #   attr_reader :runtime
          include Import[:portal, :logger, :runtime]

          desc "Install MODs from Factorio MOD Portal (downloads to mod directory and enables)"

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
            graph, mod_list, _installed_mods = load_current_state

            # Ensure mod directory exists
            runtime.mod_dir.mkpath unless runtime.mod_dir.exist?

            # Plan installation (fetch info, extend graph, validate)
            install_targets = plan_installation(mod_specs, graph, jobs)

            if install_targets.empty?
              say "All specified MODs are already installed and enabled"
              return
            end

            # Show plan
            show_plan(install_targets)
            return unless confirm?("Do you want to install these MODs?")

            # Execute installation
            execute_installation(install_targets, graph, mod_list, jobs)

            # Save mod-list.json
            mod_list.save(runtime.mod_list_path)
            say "Saved mod-list.json", prefix: :success
            logger.debug("Saved mod-list.json")
          end

          # Plan the installation by fetching MOD info and extending the graph
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param graph [Dependency::Graph] Current dependency graph
          # @param jobs [Integer] Number of parallel jobs
          # @return [Array<Hash>] Installation targets with MOD info and releases
          private def plan_installation(mod_specs, graph, jobs)
            # Create progress presenter for info fetching
            presenter = Progress::Presenter.new(
              title: "\u{1F50D}\u{FE0E} Fetching MOD info",
              output: $stderr
            )

            # Phase 1: Fetch info for target MODs
            target_infos = fetch_target_mod_info(mod_specs, jobs, presenter)

            # Phase 2: Recursively resolve dependencies and extend graph
            all_mod_infos = resolve_dependencies_with_graph(target_infos, graph, jobs, presenter)

            # Phase 3: Validate graph (cycles, conflicts)
            validate_installation_graph(graph)

            # Phase 4: Extract install targets from graph
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
          # @return [Hash] {mod_spec:, mod_info:, release:}
          private def fetch_single_mod_info(mod_spec)
            mod_name, version_spec = parse_mod_spec(mod_spec)

            # Fetch full MOD info from portal (bug fix: was portal.fetch_mod)
            mod_info = portal.get_mod_full(mod_name)

            # Find the appropriate release
            release = find_release(mod_info, version_spec)

            unless release
              raise Error, "Release not found for #{mod_name}@#{version_spec}"
            end

            {
              mod_spec:,
              mod_name:,
              version_spec:,
              mod_info:,
              release:
            }
          end

          # Parse MOD specification into name and version
          #
          # @param mod_spec [String] MOD specification
          # @return [Array<String, String>] [mod_name, version_spec]
          private def parse_mod_spec(mod_spec)
            parts = mod_spec.split("@", 2)
            mod_name = parts[0]
            version_spec = parts[1] || "latest"
            [mod_name, version_spec]
          end

          # Find the appropriate release for a version specification
          #
          # @param mod_info [Types::MODInfo] MOD information
          # @param version_spec [String] Version specification ("latest" or specific version)
          # @return [Types::MODRelease, nil] The release, or nil if not found
          private def find_release(mod_info, version_spec)
            if version_spec == "latest"
              mod_info.releases.max_by(&:released_at)
            else
              target_version = Types::MODVersion.from_string(version_spec)
              mod_info.releases.find {|r| r.version == target_version }
            end
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
                  new_dependencies << {
                    mod: dep_mod,
                    version_requirement: edge.version_requirement,
                    required_by: mod_name
                  }
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

                {
                  mod_name: dep[:mod].name,
                  mod_info:,
                  release:
                }
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

          # Find a release compatible with a version requirement
          #
          # @param mod_info [Types::MODInfo] MOD information
          # @param version_requirement [Types::MODVersionRequirement, nil] Version requirement
          # @return [Types::MODRelease, nil] Compatible release or nil
          private def find_compatible_release(mod_info, version_requirement)
            # If no requirement, use latest
            return mod_info.releases.max_by(&:released_at) if version_requirement.nil?

            # Find latest release that satisfies requirement
            compatible_releases = mod_info.releases.select {|r|
              version_requirement.satisfied_by?(r.version)
            }

            compatible_releases.max_by(&:released_at)
          end

          # Validate the installation graph
          #
          # @param graph [Dependency::Graph] Graph to validate
          # @return [void]
          # @raise [Factorix::Error] if validation fails
          private def validate_installation_graph(graph)
            # Check for cycles
            if graph.cyclic?
              # Get strongly connected components (cycles)
              cycles = graph.strongly_connected_components.select {|component| component.size > 1 }

              logger.error("Circular dependency detected. Cycles found:")
              cycles.each do |cycle|
                logger.error("  Cycle: #{cycle.join(" <-> ")}")
              end

              raise Error, "Circular dependency detected in MODs to install"
            end

            # Check for conflicts
            # For each node to be installed, check if it conflicts with existing enabled MODs
            graph.nodes.each do |node|
              next unless node.operation == :install

              graph.edges_from(node.mod).each do |edge|
                next unless edge.incompatible?

                target_node = graph.node(edge.to_mod)
                if target_node&.enabled?
                  raise Error,
                    "Cannot install #{node.mod}: it conflicts with enabled MOD #{edge.to_mod}"
                end
              end
            end
          end

          # Extract install targets from the graph
          #
          # @param graph [Dependency::Graph] Graph with install operations
          # @param all_mod_infos [Hash] All MOD infos by name
          # @return [Array<Hash>] Install targets sorted in topological order
          private def extract_install_targets(graph, all_mod_infos)
            # Sort in topological order (dependencies first)
            sorted_mods = graph.topological_order.select {|mod|
              node = graph.node(mod)
              node&.operation == :install
            }

            # Build install targets with download information
            sorted_mods.filter_map {|mod|
              info = all_mod_infos[mod.name]
              unless info
                logger.warn("No info found for #{mod}, skipping")
                next nil
              end

              output_path = runtime.mod_dir / info[:release].file_name

              {
                mod:,
                mod_info: info[:mod_info],
                release: info[:release],
                output_path:,
                category: info[:mod_info].category
              }
            }
          end

          # Show the installation plan
          #
          # @param targets [Array<Hash>] Installation targets
          # @return [void]
          private def show_plan(targets)
            say "Planning to install #{targets.size} MOD(s):"
            targets.each do |target|
              say "  - #{target[:mod]}@#{target[:release].version} (#{target[:category].name})"
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
            # Download all MODs
            download_mods(targets, jobs)

            # Add/enable all MODs in mod-list.json
            targets.each do |target|
              mod = target[:mod]

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
            end
          end

          # Download MODs in parallel
          #
          # @param targets [Array<Hash>] Installation targets
          # @param jobs [Integer] Number of parallel jobs
          # @return [void]
          private def download_mods(targets, jobs)
            # Set up multi-progress presenter
            multi_presenter = Progress::MultiPresenter.new(
              title: "\u{1F4E5}\u{FE0E} Downloads"
            )

            # Use thread pool for controlled parallelism
            pool = Concurrent::FixedThreadPool.new(jobs)

            # Submit download tasks to the pool
            futures = targets.map {|target|
              Concurrent::Future.execute(executor: pool) do
                # Get a new portal instance
                thread_portal = Application[:portal]
                thread_downloader = thread_portal.mod_download_api.downloader

                # Register progress presenter and create handler
                presenter = multi_presenter.register(
                  target[:mod].name,
                  title: target[:release].file_name
                )
                handler = Progress::DownloadHandler.new(presenter)

                # Subscribe to downloader events
                thread_downloader.subscribe(handler)

                thread_portal.download_mod(target[:release], target[:output_path])

                thread_downloader.unsubscribe(handler)
              end
            }

            # Wait for all downloads to complete
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
