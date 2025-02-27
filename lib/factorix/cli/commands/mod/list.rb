# frozen_string_literal: true

require "dry/cli"
require "factorix"
require "csv"

module Factorix
  class CLI
    module Commands
      module Mod
        # Command for listing mods
        class List < Dry::CLI::Command
          desc "List all MODs"

          option :format, type: :string, desc: "Output format (csv, markdown)"

          # List all MODs
          # @param options [Hash] The options for the command
          # @option options [String] :format Output format (csv, markdown)
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

          # Output the mod list in default format (names only)
          # @param list [Factorix::ModList] The mod list
          private def output_default(list)
            list.each do |mod, _state|
              puts mod.name
            end
          end

          # Output the mod list in CSV format
          # @param list [Factorix::ModList] The mod list
          private def output_csv(list)
            CSV do |csv|
              csv << %w[Name Enabled Version]
              list.each do |mod, state|
                version = state.version.nil? ? nil : state.version
                csv << [mod.name, state.enabled, version]
              end
            end
          end

          # Output the mod list in Markdown table format
          # @param list [Factorix::ModList] The mod list
          private def output_markdown(list)
            puts "| Name | Enabled | Version |"
            puts "| ---- | ------- | ------- |"
            list.each do |mod, state|
              puts "| #{mod.name} | #{state.enabled} | #{state.version || ""} |"
            end
          end
        end
      end
    end
  end
end
