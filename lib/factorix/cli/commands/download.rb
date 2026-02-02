# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      # Download Factorio game files from the official download API
      class Download < Base
        # @!parse
        #   # @return [Dry::Logger::Dispatcher]
        #   attr_reader :logger
        #   # @return [Runtime]
        #   attr_reader :runtime
        #   # @return [API::GameDownloadAPI]
        #   attr_reader :game_download_api
        include Import[:logger, :runtime, :game_download_api]

        # Platform mapping from Runtime to API platform identifier
        PLATFORM_MAP = {
          "MacOS" => "osx",
          "Linux" => "linux64",
          "Windows" => "win64",
          "WSL" => "win64"
        }.freeze
        private_constant :PLATFORM_MAP

        desc "Download Factorio game files"

        argument :version, required: false, default: "latest", desc: "Version (e.g., 2.0.73, latest)"

        option :build, aliases: ["-b"], default: "alpha", values: API::GameDownloadAPI::BUILDS, desc: "Build type"
        option :platform, aliases: ["-p"], values: API::GameDownloadAPI::PLATFORMS, desc: "Platform (default: auto-detect)"
        option :channel, aliases: ["-c"], default: "stable", values: API::GameDownloadAPI::CHANNELS, desc: "Release channel"
        option :directory, aliases: ["-d"], default: ".", desc: "Download directory"
        option :output, aliases: ["-o"], desc: "Output filename (default: from server)"

        example [
          "                           # Download latest stable version (auto-detect platform)",
          "2.0.73                     # Download specific version",
          "--build expansion          # Download expansion build",
          "--build headless -p linux64 # Download headless server for Linux",
          "--channel experimental     # Download experimental release",
          "-o factorio-server.tar.xz  # Specify output filename"
        ]

        # Execute the download command
        #
        # @param version [String] Version to download
        # @param build [String] Build type
        # @param platform [String, nil] Platform (nil for auto-detect)
        # @param channel [String] Release channel
        # @param directory [String] Download directory
        # @param output [String, nil] Output filename
        # @return [void]
        def call(version: "latest", build: "alpha", platform: nil, channel: "stable", directory: ".", output: nil, **)
          platform ||= detect_platform
          resolved_version = resolve_version(version, channel, build)

          download_dir = Pathname(directory).expand_path
          raise DirectoryNotFoundError, "Download directory does not exist: #{download_dir}" unless download_dir.exist?

          filename = output || resolve_filename(resolved_version, build, platform)
          output_path = download_dir / filename

          say "Downloading Factorio #{resolved_version} (#{build}/#{platform})...", prefix: :info

          download_game(resolved_version, build, platform, output_path)

          say "Downloaded to #{output_path}", prefix: :success
        end

        # Detect platform from Runtime
        #
        # @return [String] Platform identifier
        private def detect_platform
          runtime_class = runtime.class.name.split("::").last
          platform = PLATFORM_MAP[runtime_class]
          raise UnsupportedPlatformError, "Cannot auto-detect platform for #{runtime_class}" unless platform

          logger.debug("Auto-detected platform", platform:)
          platform
        end

        # Minimum supported major version
        MINIMUM_MAJOR_VERSION = 2
        private_constant :MINIMUM_MAJOR_VERSION

        # Resolve version, handling "latest" by fetching from API
        #
        # @param version [String] Version or "latest"
        # @param channel [String] Release channel
        # @param build [String] Build type
        # @return [String] Resolved version
        # @raise [InvalidArgumentError] if version is invalid or < 2.0
        private def resolve_version(version, channel, build)
          resolved = if version == "latest"
                       v = game_download_api.latest_version(channel:, build:)
                       raise InvalidArgumentError, "No #{channel} version available for #{build}" unless v

                       logger.debug("Resolved latest version", channel:, build:, version: v)
                       v
                     else
                       version
                     end

          validate_version!(resolved)
          resolved
        end

        # Validate version format and minimum version requirement
        #
        # @param version [String] Version string
        # @return [void]
        # @raise [InvalidArgumentError] if version is invalid or < 2.0
        private def validate_version!(version)
          game_version = GameVersion.from_string(version)

          return if game_version.major >= MINIMUM_MAJOR_VERSION

          raise InvalidArgumentError, "Version #{version} is not supported. Minimum version is #{MINIMUM_MAJOR_VERSION}.0.0"
        rescue VersionParseError => e
          raise InvalidArgumentError, "Invalid version format: #{e.message}"
        end

        # Resolve filename by making HEAD request
        #
        # @param version [String] Version
        # @param build [String] Build type
        # @param platform [String] Platform
        # @return [String] Filename
        private def resolve_filename(version, build, platform)
          game_download_api.resolve_filename(version:, build:, platform:)
        end

        # Download the game with progress tracking
        #
        # @param version [String] Version
        # @param build [String] Build type
        # @param platform [String] Platform
        # @param output_path [Pathname] Output file path
        # @return [void]
        private def download_game(version, build, platform, output_path)
          presenter = Progress::Presenter.new(title: output_path.basename.to_s, output: err)
          handler = Progress::DownloadHandler.new(presenter)

          game_download_api.download(version:, build:, platform:, output: output_path, handler:)
        end
      end
    end
  end
end
