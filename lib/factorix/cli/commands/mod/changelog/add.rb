# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        module Changelog
          # Add an entry to a MOD's changelog.txt
          class Add < Base
            desc "Add an entry to MOD changelog"

            option :version, required: true, desc: "Version (X.Y.Z)"
            option :category, required: true, desc: "Category (e.g., Features, Bugfixes)"
            option :changelog, default: "changelog.txt", desc: "Path to changelog file"

            argument :entry, type: :array, required: true, desc: "Entry text"

            # @param version [String] version string (X.Y.Z)
            # @param category [String] category name
            # @param entry [Array<String>] entry text words
            # @param changelog [String] path to changelog file
            # @return [void]
            def call(version:, category:, entry:, changelog: "changelog.txt", **)
              mod_version = MODVersion.from_string(version)
              path = Pathname(changelog)
              log = Factorix::Changelog.load(path)
              log.add_entry(mod_version, category, entry.join(" "))
              log.save(path)
              say "Added entry to #{mod_version} [#{category}]", prefix: :success
            end
          end
        end
      end
    end
  end
end
