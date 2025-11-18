# frozen_string_literal: true

require "tsort"

module Factorix
  module Dependency
    # Represents a collection of MOD dependencies
    #
    # This class manages a collection of Dependency::Entry objects, providing
    # filtering, validation, and circular dependency detection capabilities.
    #
    # @example Creating from dependency strings
    #   deps = Dependency::List.from_strings(["base >= 1.0.0", "? optional-mod", "! bad-mod"])
    #   deps.required.each { |dep| puts dep.to_s }
    #   deps.optional.each { |dep| puts dep.to_s }
    #
    # @example Validating dependencies
    #   available = {"base" => MODVersion.from_string("1.1.0")}
    #   puts "Missing: #{deps.missing_required(available).join(", ")}"
    #
    # @example Detecting circular dependencies
    #   mod_deps_map = {
    #     "mod-a" => Dependency::List.from_strings(["mod-b"]),
    #     "mod-b" => Dependency::List.from_strings(["mod-a"])
    #   }
    #   cycles = Dependency::List.detect_circular(mod_deps_map)
    #   cycles.each { |cycle| puts "Cycle: #{cycle.join(" -> ")}" }
    class List
      include Enumerable

      # TSort protocol implementation for dependency graph analysis
      #
      # This internal class wraps a dependency map and implements the TSort protocol
      # to enable cycle detection using strongly connected components analysis.
      class DependencyGraph
        include TSort

        # @param mod_deps_map [Hash<String, Dependency::List>] Map of MOD names to dependencies
        def initialize(mod_deps_map) = @mod_deps_map = mod_deps_map

        # Iterate through all nodes in the graph
        #
        # @yieldparam node [String] MOD name
        def tsort_each_node(&) = @mod_deps_map.each_key(&)

        # Iterate through children (dependencies) of a node
        #
        # @param node [String] MOD name
        # @yieldparam child [String] Dependent MOD name
        def tsort_each_child(node)
          deps = @mod_deps_map[node]
          return unless deps

          deps.required.each do |dep|
            yield(dep.mod.name) if @mod_deps_map.key?(dep.mod.name)
          end
        end
      end
      private_constant :DependencyGraph

      # Create List from an array of dependency strings
      #
      # @param dependency_strings [Array<String>] Array of dependency strings from info.json
      # @return [List] New instance with parsed dependencies
      # @raise [ArgumentError] if any dependency string is invalid
      #
      # @example
      #   deps = Dependency::List.from_strings(["base", "? some-mod >= 1.2.0"])
      def self.from_strings(dependency_strings)
        parser = Parser.new
        dependencies = dependency_strings.map {|str| parser.parse(str) }
        new(dependencies)
      end

      # Detect circular dependencies in a collection of MOD dependencies
      #
      # Uses TSort to detect cycles in the dependency graph.
      # Only considers required dependencies (optional and load-neutral are ignored).
      #
      # @param mod_dependencies_map [Hash<String, Dependency::List>] Map of MOD names to their dependencies
      # @return [Array<Array<String>>] Array of circular dependency chains, or empty array if none found
      #
      # @example
      #   map = {
      #     "mod-a" => Dependency::List.from_strings(["mod-b"]),
      #     "mod-b" => Dependency::List.from_strings(["mod-a"])
      #   }
      #   cycles = Dependency::List.detect_circular(map)
      #   # => [["mod-a", "mod-b", "mod-a"]]
      def self.detect_circular(mod_dependencies_map)
        graph = DependencyGraph.new(mod_dependencies_map)
        cycles = []

        # Detect self-dependencies (not detected by strongly_connected_components)
        mod_dependencies_map.each do |mod_name, deps|
          if deps.required.any? {|dep| dep.mod.name == mod_name }
            cycles << [mod_name, mod_name]
          end
        end

        # Get strongly connected components (cycles are components with size > 1)
        scc_cycles = graph.strongly_connected_components.filter_map {|component|
          next if component.size <= 1

          # Add first element at the end to make cycle explicit
          component + [component.first]
        }

        cycles + scc_cycles
      end

      # Initialize a List collection
      #
      # @param dependencies [Array<Entry>] Array of parsed dependency objects
      # @return [void]
      # @raise [ArgumentError] if dependencies is not an Array
      # @raise [ArgumentError] if any element is not a Dependency::Entry
      def initialize(dependencies=[])
        unless dependencies.is_a?(Array)
          raise ArgumentError, "dependencies must be an Array, got #{dependencies.class}"
        end

        dependencies.each_with_index do |dep, index|
          unless dep.is_a?(Entry)
            raise ArgumentError, "dependencies[#{index}] must be a Dependency::Entry, got #{dep.class}"
          end
        end

        @dependencies = dependencies.freeze
      end

      # Iterate through all dependencies
      #
      # @yieldparam dependency [Entry] Each dependency in the collection
      # @return [Enumerator] if no block is given
      # @return [List] if a block is given
      def each(&block)
        return @dependencies.to_enum unless block

        @dependencies.each(&block)
        self
      end

      # Get all required dependencies
      #
      # @return [Array<Entry>] Array of required dependencies
      def required = @dependencies.select(&:required?)

      # Get all optional dependencies (including hidden optional)
      #
      # @return [Array<Entry>] Array of optional dependencies
      def optional = @dependencies.select(&:optional?)

      # Get all incompatible dependencies
      #
      # @return [Array<Entry>] Array of incompatible dependencies
      def incompatible = @dependencies.select(&:incompatible?)

      # Get all load-neutral dependencies
      #
      # @return [Array<Entry>] Array of load-neutral dependencies
      def load_neutral = @dependencies.select(&:load_neutral?)

      # Check if this collection depends on a specific MOD
      #
      # @param mod_name_or_mod [String, MOD] MOD name or MOD instance to check
      # @return [Boolean] true if depends on the MOD (not incompatible), false otherwise
      def depends_on?(mod_name_or_mod)
        mod_name = mod_name_or_mod.is_a?(MOD) ? mod_name_or_mod.name : mod_name_or_mod.to_s

        @dependencies.any? {|dep|
          dep.mod.name == mod_name && !dep.incompatible?
        }
      end

      # Check if this collection marks a MOD as incompatible
      #
      # @param mod_name_or_mod [String, MOD] MOD name or MOD instance to check
      # @return [Boolean] true if marked as incompatible, false otherwise
      def incompatible_with?(mod_name_or_mod)
        mod_name = mod_name_or_mod.is_a?(MOD) ? mod_name_or_mod.name : mod_name_or_mod.to_s

        @dependencies.any? {|dep|
          dep.mod.name == mod_name && dep.incompatible?
        }
      end

      # Check if the collection is empty
      #
      # @return [Boolean] true if no dependencies, false otherwise
      def empty? = @dependencies.empty?

      # Get the total number of dependencies
      #
      # @return [Integer] Number of dependencies
      def size = @dependencies.size

      # Check if all required dependencies are satisfied
      #
      # @param available_mods [Hash<String, Types::MODVersion>] Available MODs and their versions
      # @return [Boolean] true if all required dependencies are satisfied
      def satisfied_by?(available_mods)
        required.all? {|dep|
          version = available_mods[dep.mod.name]
          version && dep.satisfied_by?(version)
        }
      end

      # Get list of incompatible MODs that are present
      #
      # @param available_mods [Hash<String, Types::MODVersion>] Available MODs and their versions
      # @return [Array<String>] Array of conflicting MOD names
      def conflicts_with?(available_mods)
        incompatible.filter_map {|dep|
          dep.mod.name if available_mods.key?(dep.mod.name)
        }
      end

      # Get list of missing required dependencies
      #
      # @param available_mods [Hash<String, Types::MODVersion>] Available MODs and their versions
      # @return [Array<String>] Array of missing MOD names
      def missing_required(available_mods)
        required.filter_map {|dep|
          dep.mod.name unless available_mods.key?(dep.mod.name)
        }
      end

      # Get list of dependencies with unsatisfied version requirements
      #
      # @param available_mods [Hash<String, Types::MODVersion>] Available MODs and their versions
      # @return [Hash<String, Hash<Symbol, String>>] Hash of {mod_name => {required: ..., actual: ...}}
      def unsatisfied_versions(available_mods)
        result = {}

        required.each do |dep|
          next unless dep.version_requirement # Skip if no version requirement

          version = available_mods[dep.mod.name]
          next unless version # Skip if not available (covered by missing_required)

          next if dep.satisfied_by?(version)

          result[dep.mod.name] = {
            required: dep.version_requirement.to_s,
            actual: version.to_s
          }
        end

        result
      end

      # Convert to array of dependency strings
      #
      # @return [Array<String>] Array of dependency strings
      def to_a = @dependencies.map(&:to_s)

      # Convert to hash keyed by MOD name
      #
      # @return [Hash<String, Entry>] Hash of {mod_name => dependency}
      def to_h = @dependencies.to_h {|dep| [dep.mod.name, dep] }
    end
  end
end
