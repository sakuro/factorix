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
        def self.build(installed_mods:, mod_list:) = new(installed_mods:, mod_list:).build

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

          # Get unique MODs (handle multiple versions)
          unique_mods = @installed_mods.map(&:mod)
          unique_mods.uniq!

          # Add nodes for each unique MOD
          unique_mods.each do |mod|
            add_node_for_mod(graph, mod)
          end

          # Add edges only from active versions
          # Build a map of MOD -> active version from the graph
          active_versions = graph.nodes.to_h {|node| [node.mod, node.version] }

          @installed_mods.each do |installed_mod|
            # Only add edges from the active version
            next unless active_versions[installed_mod.mod] == installed_mod.version

            add_edges_for_dependencies(graph, installed_mod)
          end

          graph
        end

        private def add_node_for_mod(graph, mod)
          version = select_version_for_mod(mod)
          enabled = mod_enabled?(mod)

          node = Node.new(mod:, version:, enabled:, installed: true)
          graph.add_node(node)
        end

        # Select which version to use for a MOD
        #
        # @param mod [Factorix::MOD] The MOD
        # @return [Factorix::Types::MODVersion] The selected version
        private def select_version_for_mod(mod)
          # Prefer version specified in mod-list.json if it exists
          if @mod_list.exist?(mod)
            specified_version = @mod_list.version(mod)
            if specified_version
              # Check if the specified version is actually installed
              installed_with_version = @installed_mods.find {|im| im.mod == mod && im.version == specified_version }
              return specified_version if installed_with_version
            end
          end

          # Otherwise, use the latest installed version
          versions_for_mod = @installed_mods.select {|im| im.mod == mod }
          versions_for_mod.max_by(&:version).version
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
            # Skip only base MOD (always available and cannot be disabled)
            # Expansion MODs can be disabled, so they must be validated
            next if dependency.mod.base?

            edge = Edge.new(from_mod:, to_mod: dependency.mod, type: dependency.type, version_requirement: dependency.version_requirement)
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
