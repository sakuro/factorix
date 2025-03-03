# frozen_string_literal: true

require "dry/cli"
require_relative "../../../mod"
require_relative "../../../mod_list"

module Factorix
  class CLI
    module Commands
      module Mod
        # Command for disabling a MOD
        class Disable < Dry::CLI::Command
          desc "Disable a MOD"

          argument :mod, required: true, desc: "The MOD to disable"
          option :verbose, type: :boolean, default: false, desc: "Print more information"

          # Disable a MOD
          # @param mod [String] The MOD to disable
          # @param options [Hash] The options for the command
          # @option options [Boolean] :verbose Print more information
          def call(mod:, **options)
            puts "Disabling MOD: #{mod}" if options[:verbose]
            list = Factorix::ModList.load
            list.disable(Factorix::Mod[name: mod])
            list.save
          end
        end
      end
    end
  end
end
