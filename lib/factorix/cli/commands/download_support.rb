# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"
require "concurrent/future"

module Factorix
  class CLI
    module Commands
      # Provides common download functionality for MOD commands
      #
      # This module extracts the common download logic used across
      # Download, Install, and Sync commands.
      #
      # @example
      #   class Install < Base
      #     include DownloadSupport
      #
      #     def call(mod_specs:, **options)
      #       # ... build targets ...
      #       download_mods(targets, jobs)
      #     end
      #   end
      module DownloadSupport
        # Download MODs in parallel
        #
        # @param targets [Array<Hash>] Download targets, each containing:
        #   - :mod [Factorix::MOD] MOD object
        #   - :release [Types::Release] Release to download
        #   - :output_path [Pathname] Output file path
        # @param jobs [Integer] Number of parallel downloads
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
      end
    end
  end
end
