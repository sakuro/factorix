# frozen_string_literal: true

require "tsort"

module Factorix
  module Dependency
    # Directed graph of MOD dependencies using TSort
    #
    # This graph represents the dependency relationships between MODs.
    # Nodes are MODs, edges are dependencies. The graph uses Ruby's TSort
    # module for topological sorting and cycle detection.
    class Graph
      include TSort

      # Create a new empty dependency graph
      def initialize
        @nodes = {}   # MOD => Node
        @edges = {}   # MOD => [Edge]
      end

      # Add a node to the graph
      #
      # @param node [Factorix::Dependency::Node] The node to add
      # @return [void]
      # @raise [ArgumentError] if a node for this MOD already exists
      def add_node(node)
        mod = node.mod
        raise ArgumentError, "Node for #{mod.name} already exists" if @nodes.key?(mod)

        @nodes[mod] = node
        @edges[mod] ||= []
      end

      # Add an edge to the graph
      #
      # @param edge [Factorix::Dependency::Edge] The edge to add
      # @return [void]
      # @raise [ArgumentError] if from_mod node doesn't exist
      def add_edge(edge)
        from_mod = edge.from_mod
        raise ArgumentError, "Node for #{from_mod.name} doesn't exist" unless @nodes.key?(from_mod)

        @edges[from_mod] ||= []
        @edges[from_mod] << edge
      end

      # Add an uninstalled MOD (Category C) to the graph
      #
      # Creates a node for an uninstalled MOD and adds edges for its dependencies.
      # Used by the install command to extend the graph with MODs fetched from the Portal API.
      #
      # @param mod_info [Types::MODInfo] MOD information from Portal API
      # @param release [Types::Release] The release to install
      # @param operation [Symbol] The operation to perform (default: :install)
      # @return [void]
      def add_uninstalled_mod(mod_info, release, operation: :install)
        mod = MOD[name: mod_info.name]

        # Skip if already in graph (might be installed or already added)
        return if node?(mod)

        # Create node for uninstalled MOD
        node = Node.new(
          mod:,
          version: release.version,
          enabled: false,
          installed: false,
          operation:
        )

        add_node(node)

        # Add edges from dependencies in info.json
        dependencies = release.info_json[:dependencies] || []
        parser = Dependency::Parser.new

        dependencies.each do |dep_string|
          dependency = parser.parse(dep_string)

          # Skip base MOD (always available)
          next if dependency.mod.base?

          edge = Edge.new(
            from_mod: mod,
            to_mod: dependency.mod,
            type: dependency.type,
            version_requirement: dependency.version_requirement
          )

          add_edge(edge)
        end
      end

      # Get a node by MOD
      #
      # @param mod [Factorix::MOD] The MOD identifier
      # @return [Factorix::Dependency::Node, nil] The node or nil if not found
      def node(mod) = @nodes[mod]

      # Get all nodes
      #
      # @return [Array<Factorix::Dependency::Node>] All nodes in the graph
      def nodes = @nodes.values

      # Get edges from a MOD
      #
      # @param mod [Factorix::MOD] The MOD identifier
      # @return [Array<Factorix::Dependency::Edge>] Edges from this MOD
      def edges_from(mod) = @edges[mod] || []

      # Get edges to a MOD
      #
      # @param mod [Factorix::MOD] The MOD identifier
      # @return [Array<Factorix::Dependency::Edge>] Edges to this MOD
      def edges_to(mod) = @edges.values.flatten.select {|edge| edge.to_mod == mod }

      # Get all edges in the graph
      #
      # @return [Array<Factorix::Dependency::Edge>] All edges
      def edges = @edges.values.flatten

      # Check if the graph contains a node for the given MOD
      #
      # @param mod [Factorix::MOD] The MOD identifier
      # @return [Boolean]
      def node?(mod) = @nodes.key?(mod)

      # Get the number of nodes in the graph
      #
      # @return [Integer]
      def size = @nodes.size

      # Check if the graph is empty
      #
      # @return [Boolean]
      def empty? = @nodes.empty?

      # Get topological order of MODs
      #
      # This returns MODs in an order where dependencies come before dependents.
      # Useful for determining installation or enabling order.
      #
      # @return [Array<Factorix::MOD>] MODs in topological order
      # @raise [TSort::Cyclic] if the graph contains cycles
      def topological_order = tsort

      # Check if the graph contains cycles
      #
      # @return [Boolean] true if the graph has cycles
      def cyclic?
        tsort
        false
      rescue TSort::Cyclic
        true
      end

      # Find strongly connected components (cycles)
      #
      # @return [Array<Array<Factorix::MOD>>] Array of cycles
      def strongly_connected_components = each_strongly_connected_component.to_a

      # TSort interface: iterate over each node
      #
      # @yield [Factorix::MOD] Each MOD in the graph
      # @return [void]
      def tsort_each_node(&) = @nodes.each_key(&)

      # TSort interface: iterate over children of a node
      #
      # @param mod [Factorix::MOD] The MOD to get children for
      # @yield [Factorix::MOD] Each child MOD
      # @return [void]
      def tsort_each_child(mod)
        edges_from(mod).each do |edge|
          # Only follow required dependency edges for cycle detection
          # Skip optional, incompatible, load-neutral, and hidden edges
          # Optional cycles are allowed in Factorio
          next unless edge.required?

          yield edge.to_mod if @nodes.key?(edge.to_mod)
        end
      end

      # Get a string representation of the graph
      #
      # @return [String]
      def to_s = "#<#{self.class.name} nodes=#{@nodes.size} edges=#{edges.size}>"

      # Detailed inspection string
      #
      # @return [String]
      def inspect
        node_list = @nodes.values.map(&:to_s).join(", ")
        "#<#{self.class.name} [#{node_list}]>"
      end
    end
  end
end
