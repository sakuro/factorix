# frozen_string_literal: true

require "csv"
require "dry/cli"
require "markdown-tables"

module Factorix
  class CLI
    module Commands
      module Mod
        # Command for listing MODs
        class List < Dry::CLI::Command
          desc "List all MODs"

          option :format, type: :string, values: %w[csv markdown], desc: "Output format"

          # List all MODs
          # @param options [Hash] The options for the command
          # @option options [String] :format Output format
          def call(**options)
            list = Factorix::ModList.load

            case options[:format]
            when "csv"
              output_csv(list)
            when "markdown"
              output_markdown(list)
            else
              output_default(list)
            end
          end

          # Output the MOD list in default format (names only)
          # @param list [Factorix::ModList] The MOD list
          private def output_default(list)
            list.each_mod do |mod|
              puts mod.name
            end
          end

          # Output the MOD list in CSV format
          # @param list [Factorix::ModList] The MOD list
          private def output_csv(list)
            CSV do |csv|
              csv << %w[Name Enabled Version]
              list.each do |mod, state|
                version = state.version.nil? ? nil : state.version
                csv << [mod.name, state.enabled, version]
              end
            end
          end

          # Output the MOD list in Markdown table format
          # @param list [Factorix::ModList] The MOD list
          private def output_markdown(list)
            labels = %w[Name Enabled Version]
            data = list.map {|mod, state|
              [mod.name, state.enabled, state.version || ""]
            }

            # Use left alignment for all columns
            table = MarkdownTables.make_table(labels, data, is_rows: true, align: "l")
            puts table
          end
        end
      end
    end
  end
end
