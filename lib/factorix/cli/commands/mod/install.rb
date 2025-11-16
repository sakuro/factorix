# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      module MOD
        # Install MODs from Factorio MOD Portal
        class Install < Dry::CLI::Command
          prepend CommonOptions

          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          #   # @return [Dry::Logger::Dispatcher]
          #   attr_reader :logger
          include Factorix::Import[:portal, :logger]

          desc "Install MODs from Factorio MOD Portal (downloads to mod directory and enables)"

          argument :mod_specs, type: :array, required: true, desc: "MOD specifications (name@version or name@latest or name)"
          option :jobs, type: :integer, aliases: ["-j"], default: 4, desc: "Number of parallel downloads"

          # Execute the install command
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param jobs [Integer] Number of parallel downloads
          # @return [void]
          def call(mod_specs:, jobs: 4, **)
            runtime = Factorix::Runtime.detect
            mod_dir = runtime.mod_dir
            mod_list_path = runtime.mod_list_path

            # Ensure mod directory exists
            mod_dir.mkpath unless mod_dir.exist?

            # Create progress presenter for info fetching
            presenter = Progress::Presenter.new(
              title: "\u{1F50E} Fetching MOD info",
              output: $stderr
            )

            # Fetch MOD info in parallel
            downloads = fetch_mod_info_parallel(mod_specs, mod_dir, jobs, presenter)

            # Resolve dependencies recursively
            resolver = MODDependencyResolver.new
            downloads = resolver.resolve_dependencies(downloads, mod_dir, jobs, presenter)

            # Download files
            download_mods(downloads, jobs)

            # Load mod-list.json
            mod_list = Factorix::MODList.load(from: mod_list_path)

            # Add all downloaded MODs to mod-list.json and enable them
            downloads.each do |download|
              mod = Factorix::MOD[name: download[:mod_name]]

              # Add to mod-list.json if not already present
              if mod_list.exist?(mod)
                # Enable if already in list
                unless mod_list.enabled?(mod)
                  mod_list.enable(mod)
                  logger.info("Enabled in mod-list.json", mod_name: mod.name)
                end
              else
                mod_list.add(mod, enabled: true)
                logger.info("Added to mod-list.json", mod_name: mod.name)
              end
            end

            # Save mod-list.json
            mod_list.save(to: mod_list_path)
            logger.info("Saved mod-list.json")
          end

          private def download_mods(downloads, jobs)
            # Set up multi-progress presenter
            multi_presenter = Progress::MultiPresenter.new(
              title: "\u{1F4E5} Downloads"
            )

            # Use thread pool for controlled parallelism
            pool = Concurrent::FixedThreadPool.new(jobs)

            # Submit download tasks to the pool
            futures = downloads.map {|download|
              Concurrent::Future.execute(executor: pool) do
                # Get a new portal instance
                thread_portal = Factorix::Application[:portal]
                thread_downloader = thread_portal.mod_download_api.downloader

                # Register progress presenter and create handler
                presenter = multi_presenter.register(
                  download[:mod_name],
                  title: download[:release].file_name
                )
                handler = Progress::DownloadHandler.new(presenter)

                # Subscribe to downloader events
                thread_downloader.subscribe(handler)

                thread_portal.download_mod(download[:release], download[:output_path])

                thread_downloader.unsubscribe(handler)
              end
            }

            # Wait for all downloads to complete
            futures.each(&:wait!)
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end

          # Fetch MOD information in parallel with progress display
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param mod_dir [Pathname] MOD directory
          # @param jobs [Integer] Number of parallel jobs
          # @param presenter [Progress::Presenter] Progress presenter
          # @return [Array<Hash>] Array of download information hashes
          private def fetch_mod_info_parallel(mod_specs, mod_dir, jobs, presenter)
            presenter.start(total: nil)

            # Use thread pool for parallel fetching
            pool = Concurrent::FixedThreadPool.new(jobs)

            # Submit fetch tasks to the pool
            futures = mod_specs.map {|mod_spec|
              Concurrent::Future.execute(executor: pool) do
                result = fetch_mod_info(mod_spec, mod_dir)
                presenter.update
                result
              end
            }

            # Wait for all fetches to complete
            results = futures.map(&:value!)

            results
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end

          # Fetch MOD information for a single MOD specification
          #
          # @param mod_spec [String] MOD specification
          # @param mod_dir [Pathname] MOD directory
          # @return [Hash] Download information hash
          private def fetch_mod_info(mod_spec, mod_dir)
            # Parse MOD specification (name@version or name)
            mod_name, version_spec = mod_spec.split("@", 2)
            version_spec ||= "latest"

            # Fetch full MOD info from portal
            mod_info = portal.fetch_mod(mod_name)

            # Determine which release to download
            release = if version_spec == "latest"
                        mod_info.releases.max_by(&:released_at)
                      else
                        target_version = Types::MODVersion.from_string(version_spec)
                        mod_info.releases.find {|r| r.version == target_version }
                      end

            unless release
              raise Factorix::Error, "Release not found for #{mod_name}@#{version_spec}"
            end

            # Build output path
            output_path = mod_dir / release.file_name

            {
              mod_name:,
              release:,
              output_path:,
              category: mod_info.category,
              dependencies_resolved: false
            }
          end
        end
      end
    end
  end
end
