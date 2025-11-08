# MOD Dependency Management

Classes for managing dependencies during MOD installation/uninstallation.

## Overview

Design for representing Factorio MOD dependencies as Ruby classes and validating dependencies during installation/uninstallation.

## Dependency Representation

Factorio MOD dependencies are defined in the `dependencies` field of `info.json` in the following format:

```
"<prefix> mod-name <comparison-operator version>"
```

### Examples

- `"base"` - Required dependency on base game
- `"? optional-mod"` - Optional dependency
- `"(?) hidden-optional-mod"` - Hidden optional dependency
- `"! incompatible-mod"` - Incompatible (conflicting) MOD
- `"~ load-neutral-mod"` - No effect on load order
- `"some-mod >= 1.2.0"` - Required dependency on version 1.2.0 or later
- `"? other-mod = 0.5.3"` - Optional dependency on version 0.5.3 only

## Class Design

### MODDependency

Immutable Data.define object representing a single MOD dependency.

```ruby
module Factorix
  MODDependency = Data.define(:mod_name, :type, :version_requirement) do
    # Constants representing dependency types
    REQUIRED = :required         # Required dependency
    OPTIONAL = :optional         # Optional dependency
    HIDDEN_OPTIONAL = :hidden    # Hidden optional dependency
    INCOMPATIBLE = :incompatible # Incompatible (conflicting)
    LOAD_NEUTRAL = :load_neutral # No effect on load order

    # @!attribute [r] mod_name
    #   @return [String] Name of dependent MOD

    # @!attribute [r] type
    #   @return [Symbol] Dependency type (:required, :optional, :hidden, :incompatible, :load_neutral)

    # @!attribute [r] version_requirement
    #   @return [Gem::Requirement, nil] Version requirement, nil if no requirement

    # Check if required dependency
    # @return [Boolean] true if required dependency
    def required?
      type == REQUIRED
    end

    # Check if optional dependency
    # @return [Boolean] true if optional dependency
    def optional?
      type == OPTIONAL || type == HIDDEN_OPTIONAL
    end

    # Check if incompatible (conflicting)
    # @return [Boolean] true if incompatible
    def incompatible?
      type == INCOMPATIBLE
    end

    # Check if load-neutral
    # @return [Boolean] true if no effect on load order
    def load_neutral?
      type == LOAD_NEUTRAL
    end

    # Check if version requirement is satisfied
    # @param version [String] Version to check
    # @return [Boolean] true if version requirement is satisfied, also true if no requirement
    def satisfied_by?(version)
      return true unless version_requirement
      version_requirement.satisfied_by?(Gem::Version.new(version))
    end

    # Return string representation
    # @return [String] String representation of dependency
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

### MODDependencyParser

Class for parsing dependency strings.

```ruby
module Factorix
  class MODDependencyParser
    # Parse dependency string
    # @param dependency_string [String] Dependency string to parse
    # @return [MODDependency] Parsed dependency object
    def self.parse(dependency_string)
      type = determine_type(dependency_string)
      clean_string = remove_prefix(dependency_string, type)

      mod_name, version_requirement = parse_mod_name_and_version(clean_string)

      MODDependency.new(
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
        MODDependency::INCOMPATIBLE
      elsif dependency_string.start_with?("(?)")
        MODDependency::HIDDEN_OPTIONAL
      elsif dependency_string.start_with?("?")
        MODDependency::OPTIONAL
      elsif dependency_string.start_with?("~")
        MODDependency::LOAD_NEUTRAL
      else
        MODDependency::REQUIRED
      end
    end

    # Remove prefix
    # @param dependency_string [String] Dependency string
    # @param type [Symbol] Dependency type
    # @return [String] String with prefix removed
    def self.remove_prefix(dependency_string, type)
      case type
      when MODDependency::INCOMPATIBLE
        dependency_string[1..-1].strip
      when MODDependency::HIDDEN_OPTIONAL
        dependency_string[3..-1].strip
      when MODDependency::OPTIONAL
        dependency_string[1..-1].strip
      when MODDependency::LOAD_NEUTRAL
        dependency_string[1..-1].strip
      else
        dependency_string.strip
      end
    end

    # Parse MOD name and version requirement
    # @param clean_string [String] String with prefix removed
    # @return [Array<String, Gem::Requirement, nil>] Pair of MOD name and version requirement
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

### MODDependencies

Class for managing all dependencies of a MOD.

```ruby
module Factorix
  class MODDependencies
    # @return [Array<MODDependency>] List of dependencies
    attr_reader :dependencies

    # Initialize new MODDependencies instance
    # @param dependencies_array [Array<String>] Array of dependency strings
    def initialize(dependencies_array = ["base"])
      @dependencies = dependencies_array.map { |dep| MODDependencyParser.parse(dep) }
    end

    # Get only required dependencies
    # @return [Array<MODDependency>] List of required dependencies
    def required_dependencies
      @dependencies.select(&:required?)
    end

    # Get only optional dependencies
    # @return [Array<MODDependency>] List of optional dependencies
    def optional_dependencies
      @dependencies.select(&:optional?)
    end

    # Get list of incompatible MODs
    # @return [Array<MODDependency>] List of incompatible MODs
    def incompatible_dependencies
      @dependencies.select(&:incompatible?)
    end

    # Check if there is a dependency on a specific MOD
    # @param mod_name [String] MOD name to check
    # @return [Boolean] true if dependency exists
    def depends_on?(mod_name)
      @dependencies.any? { |dep| dep.mod_name == mod_name && !dep.incompatible? }
    end

    # Check if incompatible with a specific MOD
    # @param mod_name [String] MOD name to check
    # @return [Boolean] true if incompatible
    def incompatible_with?(mod_name)
      @dependencies.any? { |dep| dep.mod_name == mod_name && dep.incompatible? }
    end

    # Check if dependencies are satisfied
    # @param available_mods [Hash<String, String>] Hash of available MODs and their versions
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

## Usage Example

```ruby
# Parse dependency array from info.json
dependencies_array = ["base", "? optional-mod >= 1.0.0", "! incompatible-mod", "required-mod = 2.0.0"]
mod_dependencies = Factorix::MODDependencies.new(dependencies_array)

# Available MODs and versions
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

# Check if a specific MOD can be uninstalled
mod_to_uninstall = "base"
depending_mods = available_mods.keys.select do |mod_name|
  other_mod_deps = Factorix::MODDependencies.new(get_dependencies_for(mod_name))
  other_mod_deps.depends_on?(mod_to_uninstall)
end

if depending_mods.empty?
  puts "#{mod_to_uninstall} can be uninstalled without problems"
else
  puts "#{mod_to_uninstall} cannot be uninstalled because it is depended on by the following MODs:"
  puts depending_mods.join(", ")
end
```

## Integration Method

To integrate into existing Factorix project:

1. Create `lib/factorix/mod_dependency.rb` file and implement `MODDependency` Data.define class
2. Create `lib/factorix/mod_dependency_parser.rb` file and implement `MODDependencyParser` class
3. Create `lib/factorix/mod_dependencies.rb` file and implement `MODDependencies` class
4. Add `require` statements for new files to `lib/factorix.rb`
5. Add dependency checking to MOD enable/disable and install/uninstall processing

## Type Definition (RBS)

RBS file creation recommended to ensure type safety.

## Related Documentation

- [Architecture](../architecture.md)
- [CLI Command Details](cli.md) - Install/Uninstall commands
