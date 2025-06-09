# frozen_string_literal: true

require "open-uri"
require "openssl"
require_relative "errors"
require_relative "retry_strategy"

module Factorix
  # HTTP client for downloading files with retry and resume capabilities
  class HttpClient
    # Default options for HTTP connections
    HTTP_OPTIONS = {
      open_timeout: 60,
      read_timeout: 60,
      ssl_verify_mode: OpenSSL::SSL::VERIFY_PEER
    }.freeze
    private_constant :HTTP_OPTIONS

    # Initialize a new HTTP client with retry and progress tracking capabilities
    #
    # @param retry_strategy [RetryStrategy] retry strategy for downloads
    # @param progress [#content_length_proc, #progress_proc] progress tracking callbacks
    def initialize(retry_strategy: RetryStrategy.new, progress: nil)
      @retry_strategy = retry_strategy
      @progress = progress
    end

    # Download a file from the given URL, with automatic retry and resume support.
    # If the output file exists, attempts to resume the download from the current size
    #
    # @param url [URI::HTTP] URL to download from (HTTP or HTTPS)
    # @param output [Pathname] path to save the downloaded file
    # @return [void]
    # @raise [Factorix::DownloadError] if the download fails
    # @raise [ArgumentError] if the URL is not HTTP(S)
    def download(url, output)
      raise ArgumentError, "URL must be HTTP or HTTPS" unless url.is_a?(URI::HTTP)

      @retry_strategy.with_retry do
        if output.exist?
          download_with_resume(url, output)
        else
          download_full(url, output)
        end
      end
    end

    # Download a file from scratch, without attempting to resume
    #
    # @param uri [URI::HTTP] URL to download from
    # @param output [Pathname] path to save the downloaded file
    # @return [void]
    # @raise [Factorix::DownloadError] if the download fails
    private def download_full(uri, output)
      uri.open("rb", **download_options) do |remote|
        output.binwrite(remote.read)
      end
    rescue OpenURI::HTTPError => e
      raise DownloadError, "Download failed: #{e.message}"
    end

    # Resume a partially downloaded file from its current size.
    # Falls back to full download if the server doesn't support range requests
    #
    # @param uri [URI::HTTP] URL to download from
    # @param output [Pathname] path to save the downloaded file
    # @return [void]
    # @raise [Factorix::DownloadError] if the download fails
    private def download_with_resume(uri, output)
      options = download_options.merge("Range" => "bytes=#{output.size}-")
      uri.open("rb", **options) do |remote|
        output.open("ab") do |local|
          local.write(remote.read)
        end
      end
    rescue OpenURI::HTTPError => e
      # Range Not Satisfiable - File might have changed on server, try full download
      return download_full(uri, output) if e.message.start_with?("416")

      raise DownloadError, "Download failed: #{e.message}"
    end

    # Get the HTTP options for URI#open, optionally including progress tracking
    #
    # @return [Hash] options for URI#open
    private def download_options
      return HTTP_OPTIONS if @progress.nil?

      HTTP_OPTIONS.merge(
        content_length_proc: @progress.content_length_proc,
        progress_proc: @progress.progress_proc
      )
    end
  end
end
