# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      module MOD
        # Download MOD files from Factorio MOD Portal
        class Download < Dry::CLI::Command
          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          include Factorix::Import[:portal]

          # Category emoji mapping
          CATEGORY_EMOJIS = {
            Types::Category.for("content") => "\u{1F9F1}",              # BRICK
            Types::Category.for("overhaul") => "\u{1F9F0}",             # TOOLBOX
            Types::Category.for("tweaks") => "\u{2699}\u{FE0F}",        # GEAR
            Types::Category.for("utilities") => "\u{1F6E0}\u{FE0F}",    # HAMMER AND WRENCH
            Types::Category.for("scenarios") => "\u{1F3AC}",            # CLAPPER BOARD
            Types::Category.for("mod-packs") => "\u{1F4E6}",            # PACKAGE
            Types::Category.for("localizations") => "\u{1F310}",        # GLOBE WITH MERIDIANS
            Types::Category.for("internal") => "\u{1F4DD}",             # MEMO
            Types::Category.for("") => "\u{2753}"                       # QUESTION MARK
          }.freeze
          private_constant :CATEGORY_EMOJIS

          desc "Download MOD files from Factorio MOD Portal"

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

            # Create progress presenter for info fetching
            presenter = Progress::Presenter.new(
              title: "\u{1F50E} Fetching MOD info",
              output: $stderr
            )

            # Fetch MOD info
            downloads = fetch_mod_info_parallel(mod_specs, download_dir, jobs, presenter)

            # Resolve dependencies if requested
            if recursive
              resolver = MODDependencyResolver.new
              downloads = resolver.resolve_dependencies(downloads, download_dir, jobs, presenter)
            end

            # Download files
            download_with_multi_progress(downloads, download_dir, jobs)
          end

          private def download_with_multi_progress(downloads, _download_dir, jobs)
            # Set up multi-progress presenter
            multi_presenter = Progress::MultiPresenter.new(
              # INBOX TRAY
              title: "\u{1F4E5} Downloads"
            )

            # Use thread pool for controlled parallelism
            pool = Concurrent::FixedThreadPool.new(jobs)

            # Submit download tasks to the pool
            futures = downloads.map {|download|
              Concurrent::Future.execute(executor: pool) do
                # Get a new portal instance (memoize: false)
                thread_portal = Factorix::Application[:portal]
                # Access the downloader instance used by this portal
                thread_downloader = thread_portal.mod_download_api.downloader

                # Register progress presenter and create handler
                emoji = CATEGORY_EMOJIS[download[:category]]
                presenter = multi_presenter.register(
                  download[:mod_name],
                  title: "#{emoji} #{download[:release].file_name}"
                )
                handler = Progress::DownloadHandler.new(presenter)

                # Subscribe to downloader events (includes both cache and download events)
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
          # @param download_dir [Pathname] Download directory
          # @param jobs [Integer] Number of parallel jobs
          # @param presenter [Progress::Presenter] Progress presenter to use
          # @return [Array<Hash>] Array of download information hashes
          private def fetch_mod_info_parallel(mod_specs, download_dir, jobs, presenter)
            presenter.start(total: nil)

            # Use thread pool for parallel fetching
            pool = Concurrent::FixedThreadPool.new(jobs)

            # Submit fetch tasks to the pool
            futures = mod_specs.map {|mod_spec|
              Concurrent::Future.execute(executor: pool) do
                result = fetch_mod_info(mod_spec, download_dir)
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
          # @param download_dir [Pathname] Download directory
          # @return [Hash] Download information hash
          private def fetch_mod_info(mod_spec, download_dir)
            mod_name, version = parse_mod_spec(mod_spec)

            # Get a new portal instance for this thread
            thread_portal = Factorix::Application[:portal]
            mod_info = thread_portal.get_mod_full(mod_name)

            release = find_release(mod_info, version)
            raise ArgumentError, "Release not found for #{mod_name}@#{version}" unless release

            # Security check: prevent directory traversal
            validate_filename(release.file_name)

            output_path = download_dir / release.file_name

            {
              release:,
              output_path:,
              mod_name:,
              category: mod_info.category,
              version_requirement: nil,          # Set by dependency resolver
              dependencies_resolved: false,      # Will be processed by resolver
              source: :explicit                  # Explicitly specified by user
            }
          end

          # Parse MOD specification
          #
          # @param mod_spec [String] MOD specification (name@version or name)
          # @return [Array(String, String)] mod name and version
          private def parse_mod_spec(mod_spec)
            if mod_spec.include?("@")
              mod_name, version = mod_spec.split("@", 2)
              version = "latest" if version.empty?
            else
              mod_name = mod_spec
              version = "latest"
            end

            [mod_name, version]
          end

          # Find release by version
          #
          # @param mod_info [Types::MODInfo] MOD information
          # @param version [String] Version string or "latest"
          # @return [Types::Release, nil] Release object
          private def find_release(mod_info, version)
            if version == "latest"
              mod_info.releases.max_by(&:released_at)
            else
              mod_info.releases.find {|r| r.version.to_s == version }
            end
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
