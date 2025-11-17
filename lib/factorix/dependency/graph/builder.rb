# frozen_string_literal: true

module Factorix
  module Dependency
    class Graph
      # Builds a dependency graph from installed MODs and MOD list
      #
      # The Builder constructs a Graph by:
      # 1. Creating nodes for all installed MODs
      # 2. Setting enabled state from mod-list.json
      # 3. Creating edges from dependency information in info.json
      class Builder
        # Build a dependency graph from current state
        #
        # @param installed_mods [Array<Factorix::InstalledMOD>] Installed MODs from mod directory
        # @param mod_list [Factorix::MODList] MOD list from mod-list.json
        # @return [Factorix::Dependency::Graph] The constructed graph
        def self.build(installed_mods:, mod_list:)
          new(installed_mods:, mod_list:).build
        end

        # @param installed_mods [Array<Factorix::InstalledMOD>] Installed MODs
        # @param mod_list [Factorix::MODList] MOD list
        def initialize(installed_mods:, mod_list:)
          @installed_mods = installed_mods
          @mod_list = mod_list
        end

        # Build the graph
        #
        # @return [Factorix::Dependency::Graph] The constructed graph
        def build
          graph = Graph.new

          # Add nodes for all installed MODs
          @installed_mods.each do |installed_mod|
            add_node_for_installed_mod(graph, installed_mod)

            # Add edges for all dependencies
            add_edges_for_dependencies(graph, installed_mod)
          end

          graph
        end

        private def add_node_for_installed_mod(graph, installed_mod)
          mod = installed_mod.mod
          version = installed_mod.version
          enabled = mod_enabled?(mod)

          node = Node.new(
            mod:,
            version:,
            enabled:,
            installed: true
          )

          graph.add_node(node)
        end

        # Add edges for a MOD's dependencies
        #
        # @param graph [Factorix::Dependency::Graph] The graph to add to
        # @param installed_mod [Factorix::InstalledMOD] The installed MOD
        # @return [void]
        private def add_edges_for_dependencies(graph, installed_mod)
          from_mod = installed_mod.mod
          dependencies = installed_mod.info.dependencies || []

          dependencies.each do |dependency|
            # Skip base MOD (always available)
            next if dependency.mod.base?

            edge = Edge.new(
              from_mod:,
              to_mod: dependency.mod,
              type: dependency.type,
              version_requirement: dependency.version_requirement
            )

            graph.add_edge(edge)
          end
        end

        # Check if a MOD is enabled in the MOD list
        #
        # @param mod [Factorix::MOD] The MOD to check
        # @return [Boolean] true if enabled, false otherwise
        private def mod_enabled?(mod)
          return false unless @mod_list.exist?(mod)

          @mod_list.enabled?(mod)
        end
      end
    end
  end
end
