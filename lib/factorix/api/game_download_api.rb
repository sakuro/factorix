# frozen_string_literal: true

require "json"
require "uri"

module Factorix
  module API
    # API client for downloading Factorio game files
    #
    # Corresponds to: https://wiki.factorio.com/Download_API
    class GameDownloadAPI
      # @!parse
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      #   # @return [HTTP::Client]
      #   attr_reader :client
      include Import[:logger, client: :api_http_client]

      # Base URL for game downloads
      DOWNLOAD_BASE_URL = "https://www.factorio.com"
      private_constant :DOWNLOAD_BASE_URL

      # Base URL for API endpoints
      API_BASE_URL = "https://factorio.com"
      private_constant :API_BASE_URL

      # Valid build types
      BUILDS = %w[alpha expansion demo headless].freeze
      public_constant :BUILDS

      # Valid platforms
      PLATFORMS = %w[win64 win64-manual osx linux64].freeze
      public_constant :PLATFORMS

      # Valid release channels
      CHANNELS = %w[stable experimental].freeze
      public_constant :CHANNELS

      # Initialize with thread-safe credential loading
      #
      # @param args [Hash] dependency injection arguments
      def initialize(...)
        super
        @service_credential_mutex = Mutex.new
      end

      # Fetch latest release information
      #
      # @return [Hash{Symbol => Hash}] Hash containing stable and experimental release info
      # @example Response format
      #   {
      #     stable: { alpha: "2.0.28", expansion: "2.0.28", headless: "2.0.28" },
      #     experimental: { alpha: "2.0.29", expansion: "2.0.29", headless: "2.0.29" }
      #   }
      def latest_releases
        logger.debug "Fetching latest releases"
        uri = URI.join(API_BASE_URL, "/api/latest-releases")
        response = client.get(uri)
        JSON.parse((+response.body).force_encoding(Encoding::UTF_8), symbolize_names: true)
      end

      # Get the latest version for a specific channel and build
      #
      # @param channel [String] Release channel (stable, experimental)
      # @param build [String] Build type (alpha, expansion, demo, headless)
      # @return [String, nil] Version string or nil if not available
      def latest_version(channel:, build:)
        releases = latest_releases
        releases.dig(channel.to_sym, build.to_sym)
      end

      # Resolve the download filename by making a HEAD request
      #
      # @param version [String] Game version (e.g., "2.0.28")
      # @param build [String] Build type (alpha, expansion, demo, headless)
      # @param platform [String] Platform (win64, win64-manual, osx, linux64)
      # @return [String] Filename extracted from final redirect URL
      # @raise [ArgumentError] if build or platform is invalid
      def resolve_filename(version:, build:, platform:)
        validate_build!(build)
        validate_platform!(platform)

        uri = build_download_uri(version, build, platform)
        response = client.head(uri)
        File.basename(response.uri.path)
      end

      # Download the game to the specified output path
      #
      # @param version [String] Game version (e.g., "2.0.28")
      # @param build [String] Build type (alpha, expansion, demo, headless)
      # @param platform [String] Platform (win64, win64-manual, osx, linux64)
      # @param output [Pathname] Output file path
      # @param handler [Object, nil] Event handler for download progress (optional)
      # @return [void]
      # @raise [ArgumentError] if build or platform is invalid
      def download(version:, build:, platform:, output:, handler: nil)
        validate_build!(build)
        validate_platform!(platform)

        uri = build_download_uri(version, build, platform)
        downloader = Container[:downloader]
        downloader.subscribe(handler) if handler
        begin
          downloader.download(uri, output)
        ensure
          downloader.unsubscribe(handler) if handler
        end
      end

      # Build the download URI with authentication
      #
      # @param version [String] Game version
      # @param build [String] Build type
      # @param platform [String] Platform
      # @return [URI::HTTPS] Complete download URI with credentials
      private def build_download_uri(version, build, platform)
        path = "/get-download/#{version}/#{build}/#{platform}"
        uri = URI.join(DOWNLOAD_BASE_URL, path)
        params = {username: service_credential.username, token: service_credential.token}
        uri.query = URI.encode_www_form(params)
        uri
      end

      private def service_credential
        return @service_credential if defined?(@service_credential)

        @service_credential_mutex.synchronize do
          @service_credential ||= Container[:service_credential]
        end
      end

      # Validate build type
      #
      # @param build [String] Build type to validate
      # @raise [ArgumentError] if build type is invalid
      private def validate_build!(build)
        return if BUILDS.include?(build)

        raise ArgumentError, "Invalid build type: #{build}. Valid types: #{BUILDS.join(", ")}"
      end

      # Validate platform
      #
      # @param platform [String] Platform to validate
      # @raise [ArgumentError] if platform is invalid
      private def validate_platform!(platform)
        return if PLATFORMS.include?(platform)

        raise ArgumentError, "Invalid platform: #{platform}. Valid platforms: #{PLATFORMS.join(", ")}"
      end
    end
  end
end
