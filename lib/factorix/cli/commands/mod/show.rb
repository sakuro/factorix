# frozen_string_literal: true

require "json"
require "tint_me"

module Factorix
  class CLI
    module Commands
      module MOD
        # Show detailed MOD information from portal
        class Show < Base
          # Style for MOD title (bold + underline)
          TITLE_STYLE = TIntMe[:bold, :underline]
          private_constant :TITLE_STYLE

          # Style for section headers (bold)
          HEADER_STYLE = TIntMe[:bold]
          private_constant :HEADER_STYLE

          # Style for incompatible MODs (red)
          INCOMPATIBLE_MOD_STYLE = TIntMe[:red]
          private_constant :INCOMPATIBLE_MOD_STYLE
          # @!parse
          #   # @return [Runtime]
          #   attr_reader :runtime
          include Import[:runtime]
          include PortalSupport

          desc "Show MOD details from Factorio MOD Portal"

          example [
            "some-mod          # Show details for some-mod",
            "some-mod --json   # Show details in JSON format"
          ]

          argument :mod_name, required: true, desc: "MOD name to show"

          option :json, type: :flag, default: false, desc: "Output in JSON format"

          # Execute the show command
          #
          # @param mod_name [String] MOD name to show details for
          # @param json [Boolean] output in JSON format
          # @return [void]
          # @raise [BundledMODError] if mod_name is base or an expansion MOD
          def call(mod_name:, json:, **)
            mod = Factorix::MOD[mod_name]
            raise BundledMODError, "Cannot show base MOD" if mod.base?
            raise BundledMODError, "Cannot show expansion MOD: #{mod_name}" if mod.expansion?

            mod_info = portal.get_mod_full(mod_name)
            local_status = fetch_local_status(mod_name)

            if json
              output_json(mod_info, local_status)
            else
              display_header(mod_info)
              display_basic_info(mod_info, local_status)
              display_links(mod_info)
              display_dependencies(mod_info)
              display_incompatibilities(mod_info)
            end
          end

          private def fetch_local_status(mod_name)
            mod_list = MODList.load
            mod = Factorix::MOD[mod_name]
            installed_mod = find_installed_mod(mod_name)

            enabled = mod_list.exist?(mod) && mod_list.enabled?(mod)

            {
              installed: !installed_mod.nil?,
              enabled:,
              local_version: installed_mod&.version
            }
          end

          private def find_installed_mod(mod_name)
            InstalledMOD.all.find {|m| m.mod.name == mod_name }
          rescue
            nil
          end

          private def display_header(mod_info)
            out.puts TITLE_STYLE[mod_info.title]
            out.puts
            out.puts mod_info.summary unless mod_info.summary.empty?
            out.puts
          end

          private def display_basic_info(mod_info, local_status)
            latest_release = mod_info.latest_release || mod_info.releases.max_by(&:version)
            factorio_version = latest_release&.info_json&.dig(:factorio_version)

            rows = []
            rows << ["Status", format_status(local_status)]
            rows << ["Latest Version", latest_release&.version&.to_s || "N/A"]
            if local_status[:installed] && local_status[:local_version]
              local_ver = local_status[:local_version].to_s
              latest_ver = latest_release&.version&.to_s
              update_note = latest_ver && local_ver != latest_ver ? " (update available)" : ""
              rows << ["Installed Version", "#{local_ver}#{update_note}"]
            end
            rows << ["Author", mod_info.owner]
            rows << ["Category", mod_info.category.name]
            rows << ["License", format_license(mod_info)]
            rows << ["Factorio Version", factorio_version || "N/A"]
            rows << ["Downloads", mod_info.downloads_count.to_s]

            max_label_width = rows.map {|label, _| label.length }.max
            rows.each do |label, value|
              out.puts "#{label.ljust(max_label_width)}  #{value}"
            end
            out.puts
          end

          private def output_json(mod_info, local_status)
            latest_release = mod_info.latest_release || mod_info.releases.max_by(&:version)
            factorio_version = latest_release&.info_json&.dig(:factorio_version)
            latest_ver = latest_release&.version&.to_s

            installed_version = local_status[:installed] ? local_status[:local_version]&.to_s : nil
            update_available = if local_status[:installed] && local_status[:local_version]
                                 local_status[:local_version].to_s != latest_ver
                               end

            data = {
              name: mod_info.name,
              title: mod_info.title,
              summary: mod_info.summary,
              author: mod_info.owner,
              category: mod_info.category.name,
              license: mod_info.detail&.license&.title,
              factorio_version:,
              downloads_count: mod_info.downloads_count,
              status: json_status(local_status),
              latest_version: latest_ver,
              installed_version:,
              update_available:,
              links: {
                mod_portal: "https://mods.factorio.com/mod/#{mod_info.name}",
                source: mod_info.detail&.source_url&.to_s,
                homepage: mod_info.detail&.homepage&.to_s
              },
              dependencies: latest_release&.info_json&.dig(:dependencies) || []
            }

            out.puts JSON.pretty_generate(data)
          end

          private def json_status(local_status)
            if local_status[:installed]
              local_status[:enabled] ? "enabled" : "disabled"
            else
              "not_installed"
            end
          end

          private def format_status(local_status)
            if local_status[:installed]
              local_status[:enabled] ? "Enabled" : "Disabled"
            else
              "Not installed"
            end
          end

          private def format_license(mod_info)
            return "N/A" unless mod_info.detail&.license

            mod_info.detail.license.title
          end

          private def display_links(mod_info)
            out.puts HEADER_STYLE["Links"]
            out.puts "  MOD Portal: https://mods.factorio.com/mod/#{mod_info.name}"

            if mod_info.detail
              if mod_info.detail.source_url
                out.puts "  Source: #{mod_info.detail.source_url}"
              end
              if mod_info.detail.homepage
                out.puts "  Homepage: #{mod_info.detail.homepage}"
              end
            end
            out.puts
          end

          private def display_dependencies(mod_info)
            latest_release = mod_info.latest_release || mod_info.releases.max_by(&:version)
            return unless latest_release

            dependencies = latest_release.info_json[:dependencies] || []
            return if dependencies.empty?

            parsed = dependencies.filter_map {|dep_str| parse_dependency(dep_str) }
            required = parsed.select {|d| d[:type] == :required }
            optional = parsed.select {|d| d[:type] == :optional }

            unless required.empty?
              out.puts HEADER_STYLE["Dependencies"]
              required.each {|dep| display_dependency(dep) }
              out.puts
            end

            return if optional.empty?

            out.puts HEADER_STYLE["Optional Dependencies"]
            optional.each {|dep| display_dependency(dep) }
            out.puts
          end

          private def parse_dependency(dep_str)
            # Handle prefixes: ! (incompatible), ? (optional), (?) (hidden optional), ~ (load neutral)
            case dep_str
            when /\A!\s*(.+)/
              {type: :incompatible, spec: ::Regexp.last_match(1).strip}
            when /\A\(\?\)\s*(.+)/
              {type: :hidden_optional, spec: ::Regexp.last_match(1).strip}
            when /\A\?\s*(.+)/
              {type: :optional, spec: ::Regexp.last_match(1).strip}
            when /\A~\s*(.+)/
              {type: :load_neutral, spec: ::Regexp.last_match(1).strip}
            else
              {type: :required, spec: dep_str.strip}
            end
          end

          private def display_dependency(dep)
            out.puts "  #{dep[:spec]}"
          end

          private def display_incompatibilities(mod_info)
            latest_release = mod_info.latest_release || mod_info.releases.max_by(&:version)
            return unless latest_release

            dependencies = latest_release.info_json[:dependencies] || []
            parsed = dependencies.filter_map {|dep_str| parse_dependency(dep_str) }
            incompatible = parsed.select {|d| d[:type] == :incompatible }

            return if incompatible.empty?

            out.puts HEADER_STYLE["Incompatibilities"]
            incompatible.each {|dep| out.puts "  #{INCOMPATIBLE_MOD_STYLE[dep[:spec]]}" }
            out.puts
          end
        end
      end
    end
  end
end
