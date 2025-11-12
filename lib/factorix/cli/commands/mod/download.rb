# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      module MOD
        # Download MOD files from Factorio MOD Portal
        class Download < Dry::CLI::Command
          # Progress handler for multi-bar downloads
          class ProgressHandler
            def initialize(multi_bar, mod_name, file_name)
              @multi_bar = multi_bar
              @mod_name = mod_name
              @file_name = file_name
            end

            # Handle download started event
            #
            # @param event [Dry::Events::Event] event with total_size payload
            # @return [void]
            def on_download_started(event)
              # Register bar when download starts (now we know the total size)
              @multi_bar.register(@mod_name, title: @file_name, total_size: event[:total_size])
            end

            # Handle download progress event
            #
            # @param event [Dry::Events::Event] event with current_size payload
            # @return [void]
            def on_download_progress(event)
              @multi_bar.update(@mod_name, event[:current_size])
            end

            # Handle download completed event
            #
            # @param _event [Dry::Events::Event] event (unused)
            # @return [void]
            def on_download_completed(_event)
              @multi_bar.finish(@mod_name)
            end
          end
          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          #   # @return [Transfer::HTTP]
          #   attr_reader :http
          include Factorix::Import[
            portal: "portal",
            http: "http"
          ]

          desc "Download MOD files from Factorio MOD Portal"

          argument :mod_specs, type: :array, required: true, desc: "MOD specifications (name@version or name@latest or name)"
          option :directory, type: :string, aliases: ["-d"], default: ".", desc: "Download directory"
          option :jobs, type: :integer, aliases: ["-j"], default: 4, desc: "Number of parallel downloads"

          # Execute the download command
          #
          # @param mod_specs [Array<String>] MOD specifications
          # @param directory [String] Download directory
          # @return [void]
          def call(mod_specs:, directory: ".", jobs: 4, **)
            download_dir = Pathname(directory)

            # Ensure download directory exists
            download_dir.mkpath unless download_dir.exist?

            download_with_multi_progress(mod_specs, download_dir, jobs)
          end

          private def download_with_multi_progress(mod_specs, download_dir, jobs)
            # Prepare all downloads
            downloads = mod_specs.map {|mod_spec|
              mod_name, version = parse_mod_spec(mod_spec)

              puts "Fetching information for #{mod_name}..."
              mod_info = portal.get_mod(mod_name)

              release = find_release(mod_info, version)
              raise ArgumentError, "Release not found for #{mod_name}@#{version}" unless release

              # Security check: prevent directory traversal
              validate_filename(release.file_name)

              output_path = download_dir / release.file_name

              {
                release:,
                output_path:,
                mod_name:
              }
            }

            # Set up multi-progress bar
            multi_bar = Progress::MultiBar.new(title: "Downloads")

            # Use thread pool for controlled parallelism
            pool = Concurrent::FixedThreadPool.new(jobs)

            # Submit download tasks to the pool
            futures = downloads.map {|download|
              Concurrent::Future.execute(executor: pool) do
                # Get a new portal instance (memoize: false)
                thread_portal = Factorix::Application[:portal]
                # Access the HTTP instance used by this portal
                thread_http = thread_portal.mod_download_api.downloader.http

                # Subscribe handler for this specific download
                handler = create_multi_progress_handler(
                  multi_bar,
                  download[:mod_name],
                  download[:release].file_name
                )
                thread_http.subscribe(handler)

                thread_portal.download_mod(download[:release], download[:output_path])

                thread_http.unsubscribe(handler)
              end
            }

            # Wait for all downloads to complete
            futures.each(&:wait!)
          ensure
            pool&.shutdown
            pool&.wait_for_termination
          end

          private def create_multi_progress_handler(multi_bar, mod_name, file_name)
            ProgressHandler.new(multi_bar, mod_name, file_name)
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
