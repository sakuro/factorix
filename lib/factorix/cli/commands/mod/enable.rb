# frozen_string_literal: true

require "dry/cli"
require_relative "../../../mod"
require_relative "../../../mod_list"

module Factorix
  class CLI
    module Commands
      module Mod
        # Command for enabling a MOD
        class Enable < Dry::CLI::Command
          desc "Enable a MOD"

          argument :mod, required: true, desc: "The MOD to enable"
          option :verbose, type: :boolean, default: false, desc: "Print more information"

          # Enable a MOD
          # @param mod [String] The MOD to enable
          # @param options [Hash] The options for the command
          # @option options [Boolean] :verbose Print more information
          def call(mod:, **options)
            puts "Enabling MOD: #{mod}" if options[:verbose]
            list = Factorix::ModList.load
            list.enable(Factorix::Mod[name: mod])
            list.save
          end
        end
      end
    end
  end
end
