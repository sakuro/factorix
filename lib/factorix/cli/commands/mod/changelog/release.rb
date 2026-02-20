# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        module Changelog
          # Convert the Unreleased section to a versioned release
          class Release < Base
            desc "Convert Unreleased changelog section to a versioned section"

            option :version, desc: "Version (X.Y.Z, default: from info.json)"
            option :date, desc: "Release date (YYYY-MM-DD, default: today UTC)"
            option :changelog, default: "changelog.txt", desc: "Path to changelog file"
            option :info_json, default: "info.json", desc: "Path to info.json file"

            # @param version [String, nil] version string (X.Y.Z)
            # @param date [String, nil] release date (YYYY-MM-DD)
            # @param changelog [String] path to changelog file
            # @param info_json [String] path to info.json file
            # @return [void]
            def call(version: nil, date: nil, changelog: "changelog.txt", info_json: "info.json", **)
              parsed_version = resolve_version(version, Pathname(info_json))
              release_date = date || Time.now.utc.strftime("%Y-%m-%d")
              path = Pathname(changelog)
              log = Factorix::Changelog.load(path)
              log.release_section(parsed_version, date: release_date)
              log.save(path)
              say "Converted Unreleased to #{parsed_version} (#{release_date})", prefix: :success
            end

            private def resolve_version(version, info_json_path)
              if version
                MODVersion.from_string(version)
              else
                info = InfoJSON.from_json(info_json_path.read)
                info.version
              end
            end
          end
        end
      end
    end
  end
end
