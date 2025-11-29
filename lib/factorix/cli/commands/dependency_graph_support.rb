# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      # Provides dependency graph building support for MOD commands
      #
      # This module extracts common state loading logic used across
      # enable, disable, install, uninstall, and check commands.
      #
      # @example
      #   class Enable < Base
      #     include DependencyGraphSupport
      #
      #     def call(mod_names:, **)
      #       graph, mod_list, installed_mods = load_current_state
      #       # ... command-specific logic
      #     end
      #   end
      module DependencyGraphSupport
        # Load current MOD installation state
        #
        # Loads mod-list.json, scans installed MODs, and builds
        # a dependency graph representing the current state.
        #
        # @return [Array<Factorix::Dependency::Graph, Factorix::MODList, Array<Factorix::InstalledMOD>>]
        #   Returns a tuple of [graph, mod_list, installed_mods]
        private def load_current_state
          mod_list = MODList.load(runtime.mod_list_path)

          presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Scanning MOD(s)", output: $stderr)
          handler = Progress::ScanHandler.new(presenter)
          installed_mods = InstalledMOD.all(handler:)

          graph = Dependency::Graph::Builder.build(
            installed_mods:,
            mod_list:
          )

          [graph, mod_list, installed_mods]
        end

        # Validate current MOD state and raise error if invalid
        #
        # This method performs pre-validation as recommended in the
        # dependency resolution design document. It ensures the current
        # state is valid before making any changes.
        #
        # @return [Array<Factorix::Dependency::Graph, Factorix::MODList, Array<Factorix::InstalledMOD>>]
        #   Returns a tuple of [graph, mod_list, installed_mods] if validation succeeds
        # @raise [Factorix::Error] if current state has validation errors
        private def ensure_valid_state!
          graph, mod_list, installed_mods = load_current_state

          validator = Dependency::Validator.new(
            graph,
            mod_list:,
            all_installed_mods: installed_mods
          )
          result = validator.validate

          return [graph, mod_list, installed_mods] unless result.errors?

          logger.error("Current MOD state is invalid")
          result.errors.each {|error| logger.error("  - #{error.message}") }

          raise Error, <<~MESSAGE.chomp
            Cannot proceed because current MOD installation has validation errors.

            Please fix these issues first:
              1. Run 'factorix mod check' to see all issues
              2. Fix the issues (disable conflicting MOD(s), install missing dependencies, etc.)
              3. Verify: factorix mod check
              4. Then retry your command

            Alternatively, you can start fresh by reinstalling MOD(s).
          MESSAGE
        end

        # Find all enabled MODs that have a required dependency on the given MOD
        #
        # @param mod [Factorix::MOD] the MOD to find dependents for
        # @param graph [Factorix::Dependency::Graph] dependency graph
        # @return [Array<Factorix::MOD>] MODs that depend on the given MOD
        private def find_enabled_dependents(mod, graph)
          dependents = []

          graph.nodes.each do |node|
            next unless node.enabled?

            graph.edges_from(node.mod).each do |edge|
              next unless edge.required? && edge.to_mod == mod

              dependents << node.mod
              break
            end
          end

          dependents
        end
      end
    end
  end
end
