# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      module MOD
        # Download MOD files from Factorio MOD Portal
        class Download < Base
          include DownloadSupport
          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          #   # @return [Runtime]
          #   attr_reader :runtime
          include Import[:portal, :logger, :runtime]

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
          option :recursive, type: :flag, aliases: ["-r"], default: false, desc: "Include required dependencies recursively"

          # Execute the download command
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param directory [String] Download directory
          # @param jobs [Integer] Number of parallel downloads
          # @param recursive [Boolean] Include required dependencies recursively
          # @return [void]
          def call(mod_specs:, directory: ".", jobs: 4, recursive: false, **)
            download_dir = Pathname(directory).expand_path

            raise DirectoryNotFoundError, "Download directory does not exist: #{download_dir}" unless download_dir.exist?

            if runtime.mod_dir.exist? && download_dir.realpath == runtime.mod_dir.realpath
              raise InvalidOperationError, "Cannot download to MOD directory. Use 'mod install' instead."
            end

            download_targets = plan_download(mod_specs, download_dir, jobs, recursive)

            if download_targets.empty?
              say "No MOD(s) to download", prefix: :info
              return
            end

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
            presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Fetching MOD info", output: $stderr)

            target_infos = fetch_target_mod_info(mod_specs, jobs, presenter)

            all_mod_infos = if recursive
                              resolve_dependencies(target_infos, jobs, presenter)
                            else
                              target_infos.to_h {|info| [info[:mod_name], info] }
                            end

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

          # Recursively resolve dependencies
          #
          # @param target_infos [Array<Hash>] Initial target MOD infos
          # @param jobs [Integer] Number of parallel jobs
          # @param presenter [Progress::Presenter] Progress presenter
          # @return [Hash<String, Hash>] All MOD infos by name
          private def resolve_dependencies(target_infos, jobs, presenter)
            all_mod_infos = {}
            to_process = []

            target_infos.each do |info|
              all_mod_infos[info[:mod_name]] = info
              to_process << info[:mod_name]
            end

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
          # @param release [API::Release] Release object
          # @return [Array<Hash>] Array of {mod_name:, version_requirement:, required_by:}
          private def extract_required_dependencies(release)
            info_json = release.info_json
            return [] unless info_json

            raw_deps = info_json["dependencies"] || info_json[:dependencies]
            return [] unless raw_deps

            dep_list = Dependency::List.from_strings(raw_deps)
            dep_list.required.filter_map do |entry|
              {mod_name: entry.mod.name, version_requirement: entry.version_requirement}
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

                {mod_name: dep[:mod_name], mod_info:, release:}
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
                mod: Factorix::MOD[name: info[:mod_name]],
                mod_info: info[:mod_info],
                release:,
                output_path: download_dir / release.file_name,
                category: info[:mod_info].category
              }
            end
          end

          # Validate filename for security
          #
          # @param filename [String] Filename to validate
          # @return [void]
          # @raise [InvalidArgumentError] if filename is invalid
          private def validate_filename(filename)
            raise InvalidArgumentError, "Filename is empty" if filename.nil? || filename.empty?
            raise InvalidArgumentError, "Filename contains path separators" if filename.include?(File::SEPARATOR)
            raise InvalidArgumentError, "Filename contains path separators" if File::ALT_SEPARATOR && filename.include?(File::ALT_SEPARATOR)
            raise InvalidArgumentError, "Filename contains parent directory reference" if filename.include?("..")
          end
        end
      end
    end
  end
end
