# frozen_string_literal: true

module Factorix
  module Dependency
    # Validates MOD dependencies in a graph
    #
    # Performs comprehensive validation of MOD dependencies including:
    # - Required dependencies are installed and enabled
    # - Version requirements are satisfied
    # - No conflicts between enabled MODs
    # - No circular dependencies
    class Validator
      # Initialize validator
      #
      # @param graph [Factorix::Dependency::Graph] The dependency graph to validate
      # @param mod_list [Factorix::MODList, nil] Optional MOD list for additional validation
      def initialize(graph, mod_list: nil)
        @graph = graph
        @mod_list = mod_list
      end

      # Validate the graph
      #
      # @return [Factorix::Dependency::ValidationResult]
      def validate
        result = ValidationResult.new

        validate_circular_dependencies(result)
        validate_dependencies(result)
        validate_conflicts(result)
        validate_mod_list(result) if @mod_list

        result
      end

      private def validate_circular_dependencies(result)
        return unless @graph.cyclic?

        # Get strongly connected components (cycles)
        components = @graph.strongly_connected_components
        cycles = components.select {|component| component.size > 1 }

        cycles.each do |cycle|
          mod_names = cycle.map(&:name).join(" -> ")
          result.add_error(
            type: ValidationResult::CIRCULAR_DEPENDENCY,
            message: "Circular dependency detected: #{mod_names}"
          )
        end
      end

      # Validate dependencies for all enabled MODs
      private def validate_dependencies(result)
        @graph.nodes.each do |node|
          next unless node.enabled?

          validate_node_dependencies(node, result)
        end
      end

      # Validate dependencies for a single node
      private def validate_node_dependencies(node, result)
        @graph.edges_from(node.mod).each do |edge|
          next unless edge.required?

          validate_required_dependency(node, edge, result)
        end
      end

      # Validate a single required dependency
      private def validate_required_dependency(node, edge, result)
        dependency_node = @graph.node(edge.to_mod)

        # Check if dependency is installed
        unless dependency_node
          result.add_error(
            type: ValidationResult::MISSING_DEPENDENCY,
            message: "MOD '#{node.mod.name}' requires '#{edge.to_mod.name}' which is not installed",
            mod: node.mod,
            dependency: edge.to_mod
          )
          return
        end

        # Check if dependency is enabled
        unless dependency_node.enabled?
          result.add_error(
            type: ValidationResult::DISABLED_DEPENDENCY,
            message: "MOD '#{node.mod.name}' requires '#{edge.to_mod.name}' which is not enabled",
            mod: node.mod,
            dependency: edge.to_mod
          )
          return
        end

        # Check version requirement
        return if edge.satisfied_by?(dependency_node.version)

        result.add_error(
          type: ValidationResult::VERSION_MISMATCH,
          message: "MOD '#{node.mod.name}' requires '#{edge.to_mod.name}' version " \
                   "#{edge.version_requirement}, but version #{dependency_node.version} is installed",
          mod: node.mod,
          dependency: edge.to_mod
        )
      end

      # Validate that no conflicts exist between enabled MODs
      private def validate_conflicts(result)
        @graph.nodes.each do |node|
          next unless node.enabled?

          validate_node_conflicts(node, result)
        end
      end

      # Validate conflicts for a single node
      private def validate_node_conflicts(node, result)
        @graph.edges_from(node.mod).each do |edge|
          next unless edge.incompatible?

          conflict_node = @graph.node(edge.to_mod)
          next unless conflict_node&.enabled?

          result.add_error(
            type: ValidationResult::CONFLICT,
            message: "MOD '#{node.mod.name}' conflicts with '#{edge.to_mod.name}' but both are enabled",
            mod: node.mod,
            dependency: edge.to_mod
          )
        end
      end

      # Validate MOD list consistency
      private def validate_mod_list(result)
        return unless @mod_list

        validate_mods_in_list_not_installed(result)
        validate_mods_installed_not_in_list(result)
      end

      # Warn about MODs in list but not installed
      private def validate_mods_in_list_not_installed(result)
        @mod_list.each_mod do |mod|
          next if @graph.node?(mod)

          result.add_warning(
            type: ValidationResult::MOD_IN_LIST_NOT_INSTALLED,
            message: "MOD '#{mod.name}' in mod-list.json is not installed",
            mod:
          )
        end
      end

      # Warn about installed MODs not in list
      private def validate_mods_installed_not_in_list(result)
        @graph.nodes.each do |node|
          next if @mod_list.exist?(node.mod)

          result.add_warning(
            type: ValidationResult::MOD_INSTALLED_NOT_IN_LIST,
            message: "MOD '#{node.mod.name}' is installed but not in mod-list.json",
            mod: node.mod
          )
        end
      end
    end
  end
end
