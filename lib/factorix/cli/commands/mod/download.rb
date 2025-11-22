# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      module MOD
        # Download MOD files from Factorio MOD Portal
        class Download < Base
          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          include Import[:portal, :logger]

          desc "Download MOD files from Factorio MOD Portal"

          example [
            "some-mod                 # Download latest version to current directory",
            "some-mod@1.2.0           # Download specific version",
            "-d /tmp/mods some-mod    # Download to specific directory",
            "-r some-mod              # Include required dependencies"
          ]

          argument :mod_specs, type: :array, required: true, desc: "MOD specifications (name@version or name@latest or name)"
          option :directory, type: :string, aliases: ["-d"], default: ".", desc: "Download directory"
          option :jobs, type: :integer, aliases: ["-j"], default: 4, desc: "Number of parallel downloads"
          option :recursive, type: :boolean, aliases: ["-r"], default: false, desc: "Include required dependencies recursively"

          # Execute the download command
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param directory [String] Download directory
          # @param jobs [Integer] Number of parallel downloads
          # @param recursive [Boolean] Include required dependencies recursively
          # @return [void]
          def call(mod_specs:, directory: ".", jobs: 4, recursive: false, **)
            download_dir = Pathname(directory)

            # Ensure download directory exists
            download_dir.mkpath unless download_dir.exist?

            # Plan download (fetch info, optionally resolve dependencies)
            download_targets = plan_download(mod_specs, download_dir, jobs, recursive)

            if download_targets.empty?
              say "No MODs to download"
              return
            end

            # Download files
            download_mods(download_targets, jobs)

            say "Downloaded #{download_targets.size} MOD(s)", prefix: :success
          end

          # Plan the download by fetching MOD info and optionally resolving dependencies
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param download_dir [Pathname] Download directory
          # @param jobs [Integer] Number of parallel jobs
          # @param recursive [Boolean] Include dependencies
          # @return [Array<Hash>] Download targets with MOD info and releases
          private def plan_download(mod_specs, download_dir, jobs, recursive)
            # Create progress presenter for info fetching
            presenter = Progress::Presenter.new(
              title: "\u{1F50D}\u{FE0E} Fetching MOD info",
              output: $stderr
            )

            # Phase 1: Fetch info for target MODs
            target_infos = fetch_target_mod_info(mod_specs, jobs, presenter)

            # Phase 2: Optionally resolve dependencies
            all_mod_infos = if recursive
                              resolve_dependencies(target_infos, jobs, presenter)
                            else
                              target_infos.to_h {|info| [info[:mod_name], info] }
                            end

            # Phase 3: Build download targets
            build_download_targets(all_mod_infos, download_dir)
          end

          # Fetch MOD information for target specifications
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param jobs [Integer] Number of parallel jobs
          # @param presenter [Progress::Presenter] Progress presenter
          # @return [Array<Hash>] Array of {mod_spec:, mod_name:, mod_info:, release:}
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

            futures.map(&:value!)
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end

          # Fetch information for a single MOD specification
          #
          # @param mod_spec [String] MOD specification (name@version or name)
          # @return [Hash] {mod_spec:, mod_name:, mod_info:, release:}
          private def fetch_single_mod_info(mod_spec)
            mod_name, version_spec = parse_mod_spec(mod_spec)

            mod_info = portal.get_mod_full(mod_name)
            release = find_release(mod_info, version_spec)

            raise Error, "Release not found for #{mod_name}@#{version_spec}" unless release

            {
              mod_spec:,
              mod_name:,
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
            version_spec = parts[1]
            version_spec = "latest" if version_spec.nil? || version_spec.empty?
            [mod_name, version_spec]
          end

          # Find the appropriate release for a version specification
          #
          # @param mod_info [Types::MODInfo] MOD information
          # @param version_spec [String] Version specification ("latest" or specific version)
          # @return [Types::Release, nil] The release, or nil if not found
          private def find_release(mod_info, version_spec)
            if version_spec == "latest"
              mod_info.releases.max_by(&:released_at)
            else
              target_version = Types::MODVersion.from_string(version_spec)
              mod_info.releases.find {|r| r.version == target_version }
            end
          end

          # Recursively resolve dependencies
          #
          # @param target_infos [Array<Hash>] Initial target MOD infos
          # @param jobs [Integer] Number of parallel jobs
          # @param presenter [Progress::Presenter] Progress presenter
          # @return [Hash<String, Hash>] All MOD infos by name
          private def resolve_dependencies(target_infos, jobs, presenter)
            all_mod_infos = {}
            to_process = []

            # Add target MODs to processing queue
            target_infos.each do |info|
              all_mod_infos[info[:mod_name]] = info
              to_process << info[:mod_name]
            end

            # Process dependencies recursively
            processed = Set.new

            until to_process.empty?
              current_batch = to_process.shift(jobs)
              current_batch.reject! {|mod_name| processed.include?(mod_name) }
              break if current_batch.empty?

              new_dependencies = collect_new_dependencies(current_batch, all_mod_infos, processed)
              next if new_dependencies.empty?

              presenter.increase_total(new_dependencies.size)
              fetch_and_add_dependencies(new_dependencies, all_mod_infos, jobs, presenter)

              new_dependencies.each do |dep|
                to_process << dep[:mod_name] unless processed.include?(dep[:mod_name])
              end
            end

            all_mod_infos
          end

          # Collect new dependencies from a batch of MODs
          #
          # @param batch [Array<String>] Batch of MOD names
          # @param all_mod_infos [Hash] All MOD infos by name
          # @param processed [Set<String>] Mark MODs as processed
          # @return [Array<Hash>] New dependencies to fetch
          private def collect_new_dependencies(batch, all_mod_infos, processed)
            new_dependencies = []

            batch.each do |mod_name|
              processed.add(mod_name)

              info = all_mod_infos[mod_name]
              next unless info

              deps = extract_required_dependencies(info[:release])
              deps.each do |dep|
                next if builtin_mod?(dep[:mod_name])
                next if all_mod_infos.key?(dep[:mod_name])

                new_dependencies << dep
              end
            end

            new_dependencies
          end

          # Extract required dependencies from a release
          #
          # @param release [Types::Release] Release object
          # @return [Array<Hash>] Array of {mod_name:, version_requirement:, required_by:}
          private def extract_required_dependencies(release)
            info_json = release.info_json
            return [] unless info_json

            raw_deps = info_json["dependencies"] || info_json[:dependencies]
            return [] unless raw_deps

            dep_list = Dependency::List.from_strings(raw_deps)
            dep_list.required.filter_map do |entry|
              {
                mod_name: entry.mod.name,
                version_requirement: entry.version_requirement
              }
            end
          end

          # Check if a MOD is a built-in MOD
          #
          # @param mod_name [String] MOD name
          # @return [Boolean] true if built-in
          private def builtin_mod?(mod_name) = %w[base elevated-rails quality space-age].include?(mod_name)

          # Fetch and add dependencies
          #
          # @param dependencies [Array<Hash>] Dependencies to fetch
          # @param all_mod_infos [Hash] Accumulator for all MOD infos
          # @param jobs [Integer] Number of parallel jobs
          # @param presenter [Progress::Presenter] Progress presenter
          # @return [void]
          private def fetch_and_add_dependencies(dependencies, all_mod_infos, jobs, presenter)
            pool = Concurrent::FixedThreadPool.new(jobs)

            futures = dependencies.map {|dep|
              Concurrent::Future.execute(executor: pool) do
                mod_info = portal.get_mod_full(dep[:mod_name])
                release = find_compatible_release(mod_info, dep[:version_requirement])

                unless release
                  logger.warn("Skipping dependency #{dep[:mod_name]}: No compatible release found")
                  presenter.update
                  next nil
                end

                presenter.update

                {
                  mod_name: dep[:mod_name],
                  mod_info:,
                  release:
                }
              rescue HTTPClientError => e
                logger.warn("Skipping dependency #{dep[:mod_name]}: #{e.message}")
                presenter.update
                nil
              rescue JSON::ParserError
                logger.warn("Skipping dependency #{dep[:mod_name]}: Invalid API response")
                presenter.update
                nil
              end
            }

            results = futures.filter_map(&:value!)
            results.each {|result| all_mod_infos[result[:mod_name]] = result }
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end

          # Find a release compatible with a version requirement
          #
          # @param mod_info [Types::MODInfo] MOD information
          # @param version_requirement [Types::MODVersionRequirement, nil] Version requirement
          # @return [Types::Release, nil] Compatible release or nil
          private def find_compatible_release(mod_info, version_requirement)
            return mod_info.releases.max_by(&:released_at) if version_requirement.nil?

            compatible_releases = mod_info.releases.select {|r|
              version_requirement.satisfied_by?(r.version)
            }

            compatible_releases.max_by(&:released_at)
          end

          # Build download targets from MOD infos
          #
          # @param all_mod_infos [Hash] All MOD infos by name
          # @param download_dir [Pathname] Download directory
          # @return [Array<Hash>] Download targets
          private def build_download_targets(all_mod_infos, download_dir)
            all_mod_infos.values.filter_map do |info|
              release = info[:release]
              validate_filename(release.file_name)

              {
                mod_name: info[:mod_name],
                mod_info: info[:mod_info],
                release:,
                output_path: download_dir / release.file_name,
                category: info[:mod_info].category
              }
            end
          end

          # Download MODs in parallel
          #
          # @param targets [Array<Hash>] Download targets
          # @param jobs [Integer] Number of parallel jobs
          # @return [void]
          private def download_mods(targets, jobs)
            multi_presenter = Progress::MultiPresenter.new(
              title: "\u{1F4E5}\u{FE0E} Downloads"
            )

            pool = Concurrent::FixedThreadPool.new(jobs)

            futures = targets.map {|target|
              Concurrent::Future.execute(executor: pool) do
                thread_portal = Application[:portal]
                thread_downloader = thread_portal.mod_download_api.downloader

                presenter = multi_presenter.register(
                  target[:mod_name],
                  title: target[:release].file_name
                )
                handler = Progress::DownloadHandler.new(presenter)

                thread_downloader.subscribe(handler)
                thread_portal.download_mod(target[:release], target[:output_path])
                thread_downloader.unsubscribe(handler)
              end
            }

            futures.each(&:wait!)
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end

          # Validate filename for security
          #
          # @param filename [String] Filename to validate
          # @return [void]
          # @raise [ArgumentError] if filename is invalid
          private def validate_filename(filename)
            raise ArgumentError, "Filename is empty" if filename.nil? || filename.empty?
            raise ArgumentError, "Filename contains path separators" if filename.include?(File::SEPARATOR)
            raise ArgumentError, "Filename contains path separators" if File::ALT_SEPARATOR && filename.include?(File::ALT_SEPARATOR)
            raise ArgumentError, "Filename contains parent directory reference" if filename.include?("..")
          end
        end
      end
    end
  end
end
