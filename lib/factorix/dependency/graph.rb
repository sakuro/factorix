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
          # Only follow dependency edges, not incompatibility edges
          next if edge.incompatible?

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
