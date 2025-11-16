# MOD Dependency Resolution Design

## Overview

This document describes the graph-based dependency resolution design for Factorio MOD management commands.

## Problem Statement

The current implementation of MOD management commands (`enable`, `disable`, `install`, `uninstall`) uses recursive traversal for dependency resolution. This approach has several issues:

- Complex and hard to debug
- Duplicated logic across commands
- Difficult to validate the entire state
- Hard to generate clear error messages
- State mutations during traversal make reasoning difficult

## Solution: Graph-Based Approach with Pre-Validation

Use a Directed Acyclic Graph (DAG) to represent MOD dependencies, with mandatory pre-validation to simplify operations.

### Core Principles

1. **Represent state as a graph** - Current installation state is a DAG
2. **Validate before operating** - All commands check current state validity first
3. **Operate on valid state** - Assume current state is valid, only validate changes
4. **Two-phase execution** - Plan (on graph) → Execute (on file system)

## MOD Categories

MODs in the system fall into three categories:

### A: Installed MODs (インストール済み)
- Discovered via `InstalledMOD.scan(mod_dir)`
- Have `info.json` with dependency information
- Have enabled/disabled state in `mod-list.json`
- **Always included in the graph**

### B: Target MODs (操作対象)
- Specified by user as command arguments
- Subject of the operation (install/uninstall/enable/disable)
- **Added to graph during planning**

### C: API-Available MODs (API経由で取得可能)
- Not installed but information available via Portal API
- Discovered during dependency resolution
- Candidates for download in `install` command
- **Added to graph on-demand during dependency resolution**

## Commands and MOD Categories

| Command | A (Installed) | B (Target) | C (API) | Operation |
|---------|--------------|-----------|---------|-----------|
| `check` | ✅ | ❌ | ❌ | Validate only |
| `enable` | ✅ | ✅ | △ | Enable MODs + dependencies |
| `disable` | ✅ | ✅ | ❌ | Disable MODs + dependents |
| `install` | ✅ | ✅ | ✅ | Download + install + enable |
| `uninstall` | ✅ | ✅ | ❌ | Remove files + mod-list entry |
| `download` | ❌ | ✅ | ✅ | Download only (no state) |

## Graph Structure

### Node Attributes

```ruby
class MODNode
  attr_reader :mod              # MOD object (identifier)
  attr_reader :version          # MODVersion
  attr_accessor :enabled        # Boolean - in mod-list.json?
  attr_accessor :installed      # Boolean - in mod_dir?
  attr_accessor :operation      # Symbol - :enable, :disable, :install, :uninstall, nil
end
```

### Edge Attributes

```ruby
class DependencyEdge
  attr_reader :from_mod         # MOD (dependent)
  attr_reader :to_mod           # MOD (dependency)
  attr_reader :type             # Symbol - :required, :optional, :incompatible, :hidden, :load_neutral
  attr_reader :version_requirement  # MODVersionRequirement or nil
end
```

### Graph Implementation

Use Ruby's built-in `TSort` module:
- Already in use in the codebase
- Part of standard library (no external dependencies)
- Provides topological sort and cycle detection
- Lightweight and sufficient for our needs

```ruby
require 'tsort'

class MODDependencyGraph
  include TSort

  def initialize
    @nodes = {}  # MOD => MODNode
    @edges = {}  # MOD => [DependencyEdge]
  end

  # TSort interface
  def tsort_each_node(&block)
    @nodes.each_key(&block)
  end

  def tsort_each_child(node, &block)
    @edges[node]&.each { |edge| yield edge.to_mod }
  end

  # Get installation/enable order
  def topological_order
    tsort
  end

  # Detect cycles
  def cyclic?
    tsort
    false
  rescue TSort::Cyclic
    true
  end
end
```

## The `check` Command

### Purpose

Validate the consistency of currently installed MODs without making any changes.

### Validations

1. ✅ All required dependencies are installed
2. ✅ All required dependencies are enabled (for enabled MODs)
3. ✅ Version requirements are satisfied
4. ✅ No conflicting MODs are enabled simultaneously
5. ✅ No circular dependencies exist
6. ⚠️  MODs in mod-list.json but not installed (warning)
7. ⚠️  Installed MODs not in mod-list.json (warning)

### Output Example

```
Validating MOD dependencies...

✅ All enabled MODs have their required dependencies satisfied
✅ No circular dependencies detected
✅ No conflicting MODs are enabled simultaneously

⚠️  Warnings:
  - MOD 'old-mod' in mod-list.json is not installed
  - MOD 'test-mod' v1.0.0 installed but v1.2.0 required by 'main-mod'

❌ Errors:
  - MOD 'broken-mod' requires 'missing-dep' which is not installed
  - MOD 'conflict-a' conflicts with 'conflict-b' but both are enabled

Summary: 42 enabled MODs, 2 errors, 2 warnings
```

## Pre-Validation Strategy

### Concept

**All commands (except `check`) perform pre-validation before operating.**

This ensures:
- Current state is valid before making changes
- Validation logic is centralized
- Each command only validates its changes (not entire state)
- Error messages are clear and actionable

### Implementation Pattern

```ruby
module Factorix
  module CLI
    module Commands
      module MOD
        # Shared validation mixin
        module ValidationMixin
          private def ensure_valid_state!
            graph = build_current_state_graph
            validator = MODDependencyValidator.new(graph)
            results = validator.validate

            if results.has_errors?
              logger.error("Current MOD state is invalid")
              results.errors.each { |err| logger.error(err) }
              raise Factorix::Error,
                    "Fix MOD state before proceeding. Run 'factorix mod check' for details."
            end

            results.warnings.each { |warn| logger.warn(warn) }

            graph  # Return validated graph
          end
        end

        # Example command
        class Enable < Dry::CLI::Command
          include ValidationMixin

          def call(mod_names:, **)
            # 1. Pre-validation (ensures current state is valid)
            current_graph = ensure_valid_state!

            # 2. Plan changes (only validate new nodes/edges)
            changes = plan_enable(mod_names, current_graph)
            validate_changes_only(changes)

            # 3. Execute
            execute_changes(changes)
          end

          private

          def plan_enable(mod_names, graph)
            # Add target MODs and their dependencies to graph
            # Check conflicts
            # Return execution plan
          end

          def validate_changes_only(changes)
            # Only validate new nodes/edges
            # Assume existing graph is valid
          end
        end
      end
    end
  end
end
```

## Simplified Command Logic

With pre-validation, each command's logic becomes simpler:

### `enable` Command

**Before pre-validation:**
```ruby
# Must validate entire graph after adding dependencies
- Check all dependencies (existing + new)
- Check all conflicts (existing + new)
- Check entire graph for cycles
```

**After pre-validation:**
```ruby
# Only validate changes
- Existing graph is valid → skip
- Add new nodes for target MODs
- Add new nodes for missing dependencies
- Check conflicts only for new nodes
- Check cycles only in new subgraph
```

### `disable` Command

**Before pre-validation:**
```ruby
# Must validate entire resulting graph
- Check if any MOD depends on disabled MODs
- Revalidate entire graph
```

**After pre-validation:**
```ruby
# Only check reverse dependencies
- Existing graph is valid → skip
- Find MODs that depend on targets
- Add them to disable list
- No need to revalidate existing
```

### `install` Command

**Before pre-validation:**
```ruby
# Must validate entire graph after installation
- Check all dependencies
- Check all conflicts
- Validate entire result
```

**After pre-validation:**
```ruby
# Only validate new installations
- Existing installation is valid → skip
- Fetch dependencies for new MODs (Category C)
- Validate only new MODs and their deps
- Check conflicts only with new MODs
```

### `uninstall` Command

**Before pre-validation:**
```ruby
# Must check if uninstall breaks dependencies
- Search all enabled MODs for dependencies
- Validate resulting state
```

**After pre-validation:**
```ruby
# Only check direct dependencies
- Existing graph is valid → skip
- Find MODs that depend on uninstall targets
- Error if any dependencies exist
- No need for full validation
```

## Error Messages

When pre-validation fails:

```
❌ Error: Current MOD state is invalid

Cannot enable MODs because existing installation has issues:
  - MOD 'broken-mod' requires 'missing-dep' which is not installed
  - MOD 'conflict-a' conflicts with 'conflict-b' but both are enabled

Please fix these issues first:
  1. Run 'factorix mod check' to see all issues
  2. Fix the issues:
     - Disable conflicting MODs: factorix mod disable conflict-a
     - Install missing dependencies: factorix mod install missing-dep
  3. Verify: factorix mod check
  4. Then retry: factorix mod enable <your-mods>

Alternatively, you can start fresh by reinstalling MODs.
```

## Implementation Phases

### Phase 1: Core Graph Infrastructure
- [ ] Implement `MODDependencyGraph` with TSort
- [ ] Implement `MODNode` and `DependencyEdge`
- [ ] Implement graph builder from installed MODs
- [ ] Write tests for graph operations

### Phase 2: Validation
- [ ] Implement `MODDependencyValidator`
- [ ] Implement all validation checks
- [ ] Implement `ValidationMixin` for commands
- [ ] Write tests for validation

### Phase 3: `check` Command
- [ ] Implement `Check` command
- [ ] Implement validation result formatter
- [ ] Write tests
- [ ] Manual testing with real MOD directory

### Phase 4: Refactor Existing Commands
- [ ] Refactor `enable` to use graph + pre-validation
- [ ] Refactor `disable` to use graph + pre-validation
- [ ] Refactor `install` to use graph + pre-validation
- [ ] Refactor `uninstall` to use graph + pre-validation
- [ ] Update tests for all commands

### Phase 5: Documentation and Polish
- [ ] Update command help text
- [ ] Add user documentation
- [ ] Add code documentation
- [ ] Performance testing with large MOD sets

## Benefits

### For Users
- ✅ Clear error messages about what's wrong
- ✅ Suggestions for how to fix issues
- ✅ `check` command to validate state anytime
- ✅ Safer operations (won't break existing state)

### For Developers
- ✅ Simpler command implementations
- ✅ Easier to test (pure graph operations)
- ✅ Easier to debug (visualize graph)
- ✅ Shared validation logic
- ✅ Extensible for future features

### For Maintenance
- ✅ Clear separation of concerns
- ✅ Centralized dependency logic
- ✅ No duplicated validation code
- ✅ Graph can be visualized for debugging
- ✅ Easy to add new validations

## Future Enhancements

### Graph Visualization
```bash
factorix mod check --visualize
# Generates dependency graph as DOT/PNG
```

### Dry Run Mode
```bash
factorix mod enable some-mod --dry-run
# Shows what would happen without executing
```

### Dependency Explanation
```bash
factorix mod why some-mod depends-on other-mod
# Shows dependency chain
```

### Optimization Suggestions
```bash
factorix mod check --suggest
# Suggests MODs to disable to resolve conflicts
# Suggests MODs to install to satisfy dependencies
```

## References

- Ruby TSort: https://ruby-doc.org/stdlib/libdoc/tsort/rdoc/TSort.html
- Topological Sort: https://en.wikipedia.org/wiki/Topological_sorting
- DAG: https://en.wikipedia.org/wiki/Directed_acyclic_graph
- Factorio MOD Structure: https://lua-api.factorio.com/latest/auxiliary/mod-structure.html
