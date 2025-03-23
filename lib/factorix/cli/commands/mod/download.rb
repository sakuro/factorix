# frozen_string_literal: true

require "digest"
require "pathname"
require "uri"

require_relative "../../../../factorix"
require_relative "../../../credential"
require_relative "../../../downloader"
require_relative "../../../mod_portal/api"
require_relative "../../../progress/bar"
require_relative "../../error"

module Factorix
  class CLI
    module Commands
      module Mod
        # Command to download a mod from Factorio Mod Portal
        class Download < Dry::CLI::Command
          desc "Download a mod from Factorio Mod Portal"

          argument :mod_name, required: true, desc: "Name of the mod to download"
          option :version, desc: "Version of the mod to download (default: latest)"
          option :output_directory,
            aliases: ["-d"],
            desc: "Directory to save the downloaded mod (default: current directory)"
          option :quiet, type: :boolean, default: false, desc: "Suppress progress and completion messages"

          example [
            "alien-biomes",
            "alien-biomes --version 1.1.16",
            "alien-biomes -d mods"
          ]

          # Download a mod from Factorio Mod Portal
          #
          # @param mod_name [String] Name of the mod to download
          # @param options [Hash] Command options
          # @option options [String] :version Version of the mod to download (default: latest)
          # @option options [String] :output_directory Directory to save the downloaded mod (default: current directory)
          # @option options [Boolean] :quiet Suppress progress and completion messages (default: false)
          # @raise [Factorix::ModPortal::Error] when API request fails
          # @raise [Factorix::DownloadError] when download fails
          # @raise [Factorix::CLI::FileExistsError] when output file already exists
          # @raise [Factorix::CLI::SHA1MismatchError] when SHA1 hash does not match
          def call(mod_name:, **options)
            release = find_mod_release(mod_name, options[:version])
            output_path = determine_output_path(mod_name, release.version, options[:output_directory])
            download_url = build_download_url(release.download_url)

            download_mod(download_url, output_path, release.sha1, options[:quiet])
          rescue Factorix::ModPortal::Error, Factorix::DownloadError => e
            output_path.unlink if output_path&.exist?
            raise e
          end

          private def find_mod_release(mod_name, version)
            api = Factorix::ModPortal::API.new
            mod = api.mod(mod_name)

            release = find_release(mod.releases, version)
            raise Factorix::CLI::Error, "No matching release found for version #{version}" if release.nil?

            release
          end

          private def find_release(releases, version)
            if version
              releases.find {|r| r.version == version }
            else
              releases.max_by {|r| Gem::Version.new(r.version) }
            end
          end

          private def determine_output_path(mod_name, version, output_directory)
            filename = "#{mod_name}_#{version}.zip"
            output_dir = Pathname(output_directory || Dir.pwd)

            raise DirectoryNotFoundError, "Directory does not exist: #{output_dir}" unless output_dir.exist?
            raise DirectoryNotWritableError, "Directory is not writable: #{output_dir}" unless output_dir.writable?

            output_path = output_dir / filename
            raise FileExistsError, "File already exists: #{output_path}" if output_path.exist?

            output_path
          end

          private def build_download_url(base_url)
            credential = Factorix::Credential.new
            download_url = base_url.dup
            query_params = URI.decode_www_form(download_url.query || "").to_h
            query_params[:username] = credential.username
            query_params[:token] = credential.token
            download_url.query = URI.encode_www_form(query_params)
            download_url
          end

          private def download_mod(download_url, output_path, expected_sha1, quiet)
            puts "Downloading #{output_path.basename}..." unless quiet

            download_file(download_url, output_path, quiet)
            verify_and_report(output_path, expected_sha1, quiet)
          end

          private def download_file(download_url, output_path, quiet)
            downloader = Factorix::Downloader.new(
              http_client: Factorix::HttpClient.new(
                # U+2699 GEAR + U+FE0F VARIATION SELECTOR-16
                progress: quiet ? nil : Factorix::Progress::Bar.new(title: "\u2699\uFE0F #{output_path.basename}")
              )
            )
            downloader.download(download_url, output_path)
          end

          private def verify_and_report(output_path, expected_sha1, quiet)
            unless quiet
              puts "Downloaded to #{output_path}"
              puts "Verifying SHA1 hash..."
            end

            verify_sha1(output_path, expected_sha1)
            puts "SHA1 hash verified" unless quiet
          end

          private def verify_sha1(path, expected_sha1)
            actual_sha1 = Digest::SHA1.file(path).hexdigest
            return if actual_sha1 == expected_sha1

            path.unlink
            raise SHA1MismatchError, "SHA1 hash mismatch for #{path}: expected #{expected_sha1}, got #{actual_sha1}"
          end
        end
      end
    end
  end
end
