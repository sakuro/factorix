# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"
require "tsort"

module Factorix
  # Resolves MOD dependencies recursively
  class MODDependencyResolver
    # @!parse
    #   # @return [Logger]
    #   attr_reader :logger
    include Import[:logger]

    # Resolves dependencies for the given downloads
    #
    # @param downloads [Hash{String => Hash}] Map of mod_name to download info
    # @param download_dir [Pathname] Download directory
    # @param jobs [Integer] Number of parallel jobs
    # @param presenter [Progress::Presenter] Progress presenter for status updates
    # @return [Hash{String => Hash}] Updated downloads with dependencies
    def resolve_dependencies(downloads, download_dir, jobs, presenter)
      logger.info("Starting dependency resolution...")

      # Convert array to hash for easier lookup
      downloads_hash = downloads.each_with_object({}) do |download, hash|
        hash[download[:mod_name]] = download
      end

      loop do
        # Extract mods with unresolved dependencies
        unresolved = extract_unresolved(downloads_hash)
        break if unresolved.empty?

        logger.info("Processing #{unresolved.size} mod(s) with unresolved dependencies")

        # Collect new dependencies
        new_deps = []
        new_deps_set = Set.new # Track unique dependency names
        unresolved.each do |mod_name, download|
          deps = parse_mod_dependencies(download[:release])

          deps.each do |dep|
            next unless dep.required? # Only required dependencies
            next if dep.mod.base? || dep.mod.expansion? # Skip base and expansion mods

            if downloads_hash.key?(dep.mod.name)
              # Check version compatibility
              check_version_conflict(downloads_hash[dep.mod.name], dep.version_requirement)
            elsif !new_deps_set.include?(dep.mod.name)
              # Add to new dependencies list (only if not already added)
              new_deps << {dependency: dep, required_by: mod_name}
              new_deps_set.add(dep.mod.name)
            end
          end

          # Mark as resolved
          download[:dependencies_resolved] = true
        end

        break if new_deps.empty?

        # Fetch info for new dependencies in parallel
        logger.info("Fetching info for #{new_deps.size} new dependencies...")
        new_downloads = fetch_dependency_info(new_deps, download_dir, jobs, presenter)

        # Add to downloads hash and check for circular dependencies
        new_downloads.each do |download|
          downloads_hash[download[:mod_name]] = download

          # Check if any of the new mod's dependencies create a cycle
          deps = parse_mod_dependencies(download[:release])
          deps.select(&:required?).each do |dep|
            # Build the chain: find who required this mod
            new_deps.find {|d| d[:dependency].mod.name == download[:mod_name] }
            detect_circular_dependency(downloads_hash, dep.mod.name, [download[:mod_name]])
          end
        end
      end

      logger.info("Dependency resolution complete. Total mods: #{downloads_hash.size}")

      presenter.finish

      # Sort in dependency order (dependencies first)
      topological_sort(downloads_hash)
    end

    private def extract_unresolved(downloads)
      downloads.select {|_name, info| info[:dependencies_resolved] == false }
    end

    # Parse dependencies from release info_json
    #
    # @param release [Types::Release] Release object
    # @return [Array<MODDependency>] Array of dependencies
    private def parse_mod_dependencies(release)
      return [] unless release.info_json
      return [] unless release.info_json[:dependencies]

      parser = MODDependencyParser.new
      dependencies = release.info_json[:dependencies]

      dependencies.filter_map do |dep_str|
        parser.parse(dep_str)
      rescue Parslet::ParseFailed => e
        logger.warn("Failed to parse dependency: #{dep_str} - #{e.message}")
        nil
      end
    end

    # Check version compatibility
    #
    # @param existing [Hash] Existing download info
    # @param requirement [MODVersionRequirement, nil] Version requirement
    # @raise [ArgumentError] If version conflict detected
    private def check_version_conflict(existing, requirement)
      return unless requirement # No requirement means any version is OK

      existing_version = existing[:release].version

      unless requirement.satisfied_by?(existing_version)
        raise ArgumentError,
          "Version conflict for #{existing[:mod_name]}: " \
          "existing version #{existing_version} does not satisfy requirement #{requirement.operator} #{requirement.version}"
      end

      # Update version requirement if more restrictive
      if existing[:version_requirement].nil? ||
         more_restrictive?(requirement, existing[:version_requirement])

        existing[:version_requirement] = requirement
      end
    end

    # Check if a requirement is more restrictive
    #
    # @param req1 [MODVersionRequirement] First requirement
    # @param req2 [MODVersionRequirement] Second requirement
    # @return [Boolean] True if req1 is more restrictive
    private def more_restrictive?(req1, req2)
      # Simple heuristic: >= with higher version is more restrictive
      case [req1.operator, req2.operator]
      when [">=", ">="]
        req1.version > req2.version
      when ["=", _]
        true # Exact version is most restrictive
      else
        false
      end
    end

    # Detect circular dependencies
    #
    # @param downloads [Hash{String => Hash}] Downloads hash
    # @param mod_name [String] MOD name to check
    # @param chain [Array<String>] Current dependency chain
    # @raise [ArgumentError] If circular dependency detected
    private def detect_circular_dependency(downloads, mod_name, chain)
      # If the mod_name appears in the chain, we have a cycle
      if chain.include?(mod_name)
        cycle = chain + [mod_name]
        raise ArgumentError, "Circular dependency detected: #{cycle.join(" -> ")}"
      end

      # If the mod is already downloaded and resolved, check its dependencies
      return unless downloads.key?(mod_name)

      # Get dependencies of this mod (even if not yet resolved, if we have the release)
      return unless downloads[mod_name][:release]

      deps = parse_mod_dependencies(downloads[mod_name][:release])
      deps.select(&:required?).each do |dep|
        # Recursively check each dependency
        detect_circular_dependency(downloads, dep.mod.name, chain + [mod_name])
      end
    end

    # Sort downloads in dependency order (dependencies first)
    #
    # @param downloads_hash [Hash{String => Hash}] Downloads hash
    # @return [Array<Hash>] Sorted array of downloads
    private def topological_sort(downloads_hash)
      # Create a hash for TSort
      graph = Hash.new {|h, k| h[k] = [] }

      # Build dependency graph
      downloads_hash.each do |mod_name, download|
        deps = parse_mod_dependencies(download[:release])
        deps.select(&:required?).each do |dep|
          # mod_name depends on dep.mod.name
          graph[mod_name] << dep.mod.name if downloads_hash.key?(dep.mod.name)
        end
        # Ensure all nodes are in the graph
        graph[mod_name] ||= []
      end

      # Use TSort to get dependency order
      sorted_names = TSort.tsort(
        ->(&b) { graph.each_key(&b) },
        ->(n, &b) { graph[n].each(&b) }
      )

      # Convert back to download objects
      sorted_names.map {|name| downloads_hash[name] }
    end

    # Fetch info for new dependencies in parallel
    #
    # @param dependencies [Array<Hash>] Dependencies to fetch with metadata
    # @param download_dir [Pathname] Download directory
    # @param jobs [Integer] Number of parallel jobs
    # @param presenter [Progress::Presenter] Progress presenter for status updates
    # @return [Array<Hash>] Array of download info hashes
    private def fetch_dependency_info(dependencies, download_dir, jobs, presenter)
      pool = Concurrent::FixedThreadPool.new(jobs)

      futures = dependencies.map {|dep_info|
        Concurrent::Future.execute(executor: pool) do
          result = fetch_single_dependency(dep_info[:dependency], download_dir)
          presenter.update
          result
        end
      }

      results = futures.map(&:value!)

      results.compact
    ensure
      pool&.shutdown
      pool&.wait_for_termination
    end

    # Fetch info for a single dependency
    #
    # @param dep [MODDependency] Dependency to fetch
    # @param download_dir [Pathname] Download directory
    # @return [Hash, nil] Download info hash or nil if failed
    private def fetch_single_dependency(dep, download_dir)
      portal = Factorix::Application[:portal]
      mod_info = portal.get_mod_full(dep.mod.name)

      # Find latest version that satisfies requirement
      release = find_compatible_release(mod_info, dep.version_requirement)

      unless release
        logger.warn("No compatible version found for #{dep.mod.name} #{dep.version_requirement}")
        return nil
      end

      output_path = download_dir / release.file_name

      {
        release:,
        output_path:,
        mod_name: dep.mod.name,
        category: mod_info.category,
        version_requirement: dep.version_requirement,
        dependencies_resolved: false,
        source: :dependency
      }
    rescue => e
      logger.error("Failed to fetch dependency #{dep.mod.name}: #{e.message}")
      nil
    end

    # Find a compatible release for the given version requirement
    #
    # @param mod_info [Types::MODInfo] MOD info
    # @param requirement [MODVersionRequirement, nil] Version requirement
    # @return [Types::Release, nil] Compatible release or nil
    private def find_compatible_release(mod_info, requirement)
      releases = mod_info.releases || []

      return releases.first if requirement.nil? # No requirement, use latest

      # Find latest version that satisfies requirement
      compatible = releases.select {|release|
        requirement.satisfied_by?(release.version)
      }

      compatible.first # Already sorted by version descending
    end
  end
end
