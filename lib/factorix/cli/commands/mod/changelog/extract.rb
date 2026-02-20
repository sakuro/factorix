# frozen_string_literal: true

require "json"

module Factorix
  class CLI
    module Commands
      module MOD
        module Changelog
          # Extract a specific version's changelog section
          class Extract < Base
            desc "Extract a changelog section for a specific version"

            option :version, required: true, desc: "Version (X.Y.Z or Unreleased)"
            option :json, type: :flag, default: false, desc: "Output in JSON format"
            option :changelog, default: "changelog.txt", desc: "Path to changelog file"

            # @param version [String] version string (X.Y.Z or Unreleased)
            # @param json [Boolean] output in JSON format
            # @param changelog [String] path to changelog file
            # @return [void]
            def call(version:, json: false, changelog: "changelog.txt", **)
              target_version = version.casecmp("unreleased").zero? ? Factorix::Changelog::UNRELEASED : MODVersion.from_string(version)
              log = Factorix::Changelog.load(Pathname(changelog))
              section = log.find_section(target_version)

              if json
                out.puts JSON.pretty_generate(version: section.version.to_s, date: section.date, entries: section.categories)
              else
                out.puts log.format_section(section)
              end
            end
          end
        end
      end
    end
  end
end
