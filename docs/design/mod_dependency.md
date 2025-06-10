# Factorio MOD Dependency Class Design

## Overview

This document proposes a class design for representing Factorio mod dependencies. Dependencies are defined in the `dependencies` field of Factorio's info.json file and can contain complex conditions.

## Dependency Representation

Factorio mod dependencies are defined in the following format:
`"<prefix> mod_name <comparison_operator version>"`

Examples:
- `"base"` - Required dependency on base game
- `"? optional-mod"` - Optional dependency
- `"! incompatible-mod"` - Incompatible (conflicting) mod
- `"some-mod >= 1.2.0"` - Required dependency on version 1.2.0 or higher
- `"? other-mod = 0.5.3"` - Optional dependency on version 0.5.3 only

## Class Design

### `ModDependency` Class

An immutable data class representing a single mod dependency

```ruby
module Factorix
  ModDependency = Data.define(:mod_name, :type, :version_requirement) do
    # Constants representing dependency types
    REQUIRED = :required         # Required dependency
    OPTIONAL = :optional         # Optional dependency
    HIDDEN_OPTIONAL = :hidden    # Hidden optional dependency
    INCOMPATIBLE = :incompatible # Incompatible (conflicting)
    LOAD_NEUTRAL = :load_neutral # Does not affect load order

    # @!attribute [r] mod_name
    #   @return [String] Name of the dependent mod

    # @!attribute [r] type
    #   @return [Symbol] Type of dependency (:required, :optional, :hidden, :incompatible, :load_neutral)

    # @!attribute [r] version_requirement
    #   @return [Gem::Requirement, nil] Version requirement, nil if no requirement

    # Check if dependency is required
    # @return [Boolean] true if dependency is required
    def required?
      type == REQUIRED
    end

    # Check if dependency is optional
    # @return [Boolean] true if dependency is optional
    def optional?
      type == OPTIONAL || type == HIDDEN_OPTIONAL
    end

    # Check if dependency is incompatible (conflicting)
    # @return [Boolean] true if dependency is incompatible
    def incompatible?
      type == INCOMPATIBLE
    end

    # Check if dependency does not affect load order
    # @return [Boolean] true if dependency does not affect load order
    def load_neutral?
      type == LOAD_NEUTRAL
    end

    # Check if version requirement is satisfied
    # @param version [String] Version to check
    # @return [Boolean] true if version requirement is satisfied, true if no requirement
    def satisfied_by?(version)
      return true unless version_requirement
      version_requirement.satisfied_by?(Gem::Version.new(version))
    end

    # Return string representation
    # @return [String] String representation of the dependency
    def to_s
      result = case type
               when REQUIRED then ""
               when OPTIONAL then "? "
               when HIDDEN_OPTIONAL then "(?) "
               when INCOMPATIBLE then "! "
               when LOAD_NEUTRAL then "~ "
               end

      result += mod_name
      result += " #{version_requirement}" if version_requirement
      result
    end
  end
end
```

### `ModDependencyParser` Class

Parser class for parsing dependency strings

```ruby
module Factorix
  class ModDependencyParser
    # Parse dependency string
    # @param dependency_string [String] Dependency string to parse
    # @return [ModDependency] Parsed dependency object
    def self.parse(dependency_string)
      type = determine_type(dependency_string)
      clean_string = remove_prefix(dependency_string, type)

      mod_name, version_requirement = parse_mod_name_and_version(clean_string)

      ModDependency.new(
        mod_name: mod_name,
        type: type,
        version_requirement: version_requirement
      )
    end

    private

    # Determine dependency type
    # @param dependency_string [String] Dependency string
    # @return [Symbol] Dependency type
    def self.determine_type(dependency_string)
      if dependency_string.start_with?("!")
        ModDependency::INCOMPATIBLE
      elsif dependency_string.start_with?("?")
        ModDependency::OPTIONAL
      elsif dependency_string.start_with?("(?)")
        ModDependency::HIDDEN_OPTIONAL
      elsif dependency_string.start_with?("~")
        ModDependency::LOAD_NEUTRAL
      else
        ModDependency::REQUIRED
      end
    end

    # Remove prefix
    # @param dependency_string [String] Dependency string
    # @param type [Symbol] Dependency type
    # @return [String] String with prefix removed
    def self.remove_prefix(dependency_string, type)
      case type
      when ModDependency::INCOMPATIBLE
        dependency_string[1..-1].strip
      when ModDependency::OPTIONAL
        dependency_string[1..-1].strip
      when ModDependency::HIDDEN_OPTIONAL
        dependency_string[3..-1].strip
      when ModDependency::LOAD_NEUTRAL
        dependency_string[1..-1].strip
      else
        dependency_string.strip
      end
    end

    # Parse mod name and version requirement
    # @param clean_string [String] String with prefix removed
    # @return [Array<String, Gem::Requirement, nil>] Pair of mod name and version requirement
    def self.parse_mod_name_and_version(clean_string)
      operators = [">", ">=", "=", "<=", "<"]

      operator_index = operators.map do |op|
        [op, clean_string.index(" #{op} ")]
      end.reject { |_, idx| idx.nil? }.min_by { |_, idx| idx }

      if operator_index.nil?
        # No version requirement
        [clean_string, nil]
      else
        operator, index = operator_index
        mod_name = clean_string[0...index].strip
        version_string = clean_string[(index + operator.length + 1)..-1].strip
        [mod_name, Gem::Requirement.new("#{operator} #{version_string}")]
      end
    end
  end
end
```

### `ModDependencies` Class

Class for managing all dependencies of a mod

```ruby
module Factorix
  class ModDependencies
    # @return [Array<ModDependency>] List of dependencies
    attr_reader :dependencies

    # Initialize new ModDependencies instance
    # @param dependencies_array [Array<String>] Array of dependency strings
    def initialize(dependencies_array = ["base"])
      @dependencies = dependencies_array.map { |dep| ModDependencyParser.parse(dep) }
    end

    # Get only required dependencies
    # @return [Array<ModDependency>] List of required dependencies
    def required_dependencies
      @dependencies.select(&:required?)
    end

    # Get only optional dependencies
    # @return [Array<ModDependency>] List of optional dependencies
    def optional_dependencies
      @dependencies.select(&:optional?)
    end

    # Get list of conflicting mods
    # @return [Array<ModDependency>] List of conflicting mods
    def incompatible_dependencies
      @dependencies.select(&:incompatible?)
    end

    # Check if there is a dependency on a specific mod
    # @param mod_name [String] Mod name to check
    # @return [Boolean] true if there is a dependency
    def depends_on?(mod_name)
      @dependencies.any? { |dep| dep.mod_name == mod_name && !dep.incompatible? }
    end

    # Check if incompatible with a specific mod
    # @param mod_name [String] Mod name to check
    # @return [Boolean] true if incompatible
    def incompatible_with?(mod_name)
      @dependencies.any? { |dep| dep.mod_name == mod_name && dep.incompatible? }
    end

    # Check if dependencies are satisfied
    # @param available_mods [Hash<String, String>] Hash of available mods and their versions
    # @return [Boolean] true if all required dependencies are satisfied
    def satisfied_by?(available_mods)
      required_dependencies.all? do |dep|
        version = available_mods[dep.mod_name]
        version && dep.satisfied_by?(version)
      end
    end

    # Return dependencies as string array
    # @return [Array<String>] Array of dependency strings
    def to_a
      @dependencies.map(&:to_s)
    end
  end
end
```

## Usage Examples

```ruby
# Parse dependency array from info.json
dependencies_array = ["base", "? optional-mod >= 1.0.0", "! incompatible-mod", "required-mod = 2.0.0"]
mod_dependencies = Factorix::ModDependencies.new(dependencies_array)

# Available mods and versions
available_mods = {
  "base" => "1.1.0",
  "optional-mod" => "1.2.0",
  "required-mod" => "2.0.0"
}

# Check if dependencies are satisfied
if mod_dependencies.satisfied_by?(available_mods)
  puts "All dependencies are satisfied"
else
  puts "Dependencies are not satisfied"
end

# Check if a specific mod can be uninstalled
mod_to_uninstall = "base"
depending_mods = available_mods.keys.select do |mod_name|
  other_mod_deps = Factorix::ModDependencies.new(get_dependencies_for(mod_name))
  other_mod_deps.depends_on?(mod_to_uninstall)
end

if depending_mods.empty?
  puts "#{mod_to_uninstall} can be uninstalled without issues"
else
  puts "#{mod_to_uninstall} cannot be uninstalled because it is depended on by the following mods:"
  puts depending_mods.join(", ")
end
```

## Integration Method

To integrate this class design into the existing Factorix project:

1. Create `lib/factorix/mod_dependency.rb` file and implement the `ModDependency` data class
2. Create `lib/factorix/mod_dependency_parser.rb` file and implement the `ModDependencyParser` class
3. Create `lib/factorix/mod_dependencies.rb` file and implement the `ModDependencies` class
4. Add `require` statements for the new files in `lib/factorix.rb`
5. Use these classes to add dependency checking to mod enable/disable and install/uninstall processes

## Type Definitions (RBS)

It is recommended to create RBS files to ensure type safety.
