# frozen_string_literal: true

require "json"

module Factorix
  class CLI
    module Commands
      module MOD
        # Search MODs on Factorio MOD Portal
        class Search < Base
          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          #   # @return [Runtime]
          #   attr_reader :runtime
          include Import[:portal, :runtime]

          desc "Search MOD(s) on Factorio MOD Portal"

          example [
            "                           # List MOD(s) for current Factorio version",
            "mod-a mod-b                # Search specific MOD(s) by name",
            "--sort name                # List MOD(s) sorted by name",
            "--page 2 --page-size 25    # Paginate results",
            "--no-hide-deprecated       # Include deprecated MOD(s)",
            "--version 1.1              # Filter by specific Factorio version"
          ]

          argument :mod_names, type: :array, required: false, default: [], desc: "MOD names to search"

          option :hide_deprecated, type: :boolean, default: true, desc: "Hide deprecated MOD(s)"
          option :page, default: "1", desc: "Page number"
          option :page_size, default: "25", desc: "Results per page (max 500)"
          option :sort, values: %w[name created_at updated_at], desc: "Sort field"
          option :sort_order, values: %w[asc desc], desc: "Sort order"
          option :version, desc: "Filter by Factorio version (default: installed version)"
          option :json, type: :flag, default: false, desc: "Output in JSON format"

          # Execute the search command
          #
          # @param mod_names [Array<String>] MOD names to search
          # @param hide_deprecated [Boolean] Hide deprecated MODs
          # @param page [Integer] Page number
          # @param page_size [Integer] Results per page
          # @param sort [String, nil] Sort field
          # @param sort_order [String, nil] Sort order
          # @param version [String, nil] Factorio version filter
          # @param json [Boolean] Output in JSON format
          # @return [void]
          def call(mod_names: [], hide_deprecated: true, page: "1", page_size: "25", sort: nil, sort_order: nil, version: nil, json: false, **)
            page = Integer(page)
            page_size = Integer(page_size)
            version ||= default_factorio_version

            mods = portal.list_mods(*mod_names, hide_deprecated: hide_deprecated || nil, page:, page_size:, sort:, sort_order:, version:)

            if json
              output_json(mods)
            else
              output_table(mods)
            end
          end

          private def output_json(mods)
            out.puts JSON.pretty_generate(mods.map {|mod| mod_to_hash(mod) })
          end

          private def mod_to_hash(mod)
            {
              name: mod.name,
              title: mod.title,
              owner: mod.owner,
              summary: mod.summary,
              downloads_count: mod.downloads_count,
              category: mod.category.value,
              score: mod.score,
              thumbnail: mod.thumbnail&.to_s,
              latest_release: mod.latest_release && release_to_hash(mod.latest_release),
              releases: mod.releases.map {|r| release_to_hash(r) }
            }
          end

          private def release_to_hash(release)
            {
              version: release.version.to_s,
              file_name: release.file_name,
              released_at: release.released_at.iso8601,
              factorio_version: release.info_json[:factorio_version],
              sha1: release.sha1
            }
          end

          private def output_table(mods)
            if mods.empty?
              say "No MOD(s) found", prefix: :info
              return
            end

            rows = mods.map {|mod| format_row(mod) }

            headers = %w[NAME TITLE CATEGORY OWNER LATEST]
            widths = headers.map.with_index {|h, i| [h.length, *rows.map {|r| r[i].to_s.length }].max }

            out.puts format_table_row(headers, widths)

            rows.each do |row|
              out.puts format_table_row(row, widths)
            end

            say "#{mods.size} MOD(s) found", prefix: :info
          end

          private def format_table_row(values, widths)
            pairs = values.zip(widths)
            pairs.map {|v, w| v.to_s.ljust(w) }.join("  ")
          end

          private def format_row(mod)
            [
              mod.name,
              mod.title,
              mod.category.name,
              mod.owner,
              mod.latest_release&.version&.to_s
            ]
          end

          private def default_factorio_version
            base_mod = InstalledMOD.from_directory(runtime.data_dir + "base")
            "#{base_mod.version.major}.#{base_mod.version.minor}"
          end
        end
      end
    end
  end
end
