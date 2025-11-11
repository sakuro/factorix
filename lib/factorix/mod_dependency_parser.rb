# frozen_string_literal: true

module Factorix
  # Parser for MOD dependency strings
  #
  # This class parses dependency strings from info.json files and converts them
  # into MODDependency objects.
  #
  # @example Parsing various dependency formats
  #   parser = MODDependencyParser.new
  #
  #   # Required dependency
  #   dep1 = parser.parse("base")
  #
  #   # Optional dependency with version
  #   dep2 = parser.parse("? some-mod >= 1.2.0")
  #
  #   # Incompatible MOD
  #   dep3 = parser.parse("! bad-mod")
  #
  #   # Hidden optional
  #   dep4 = parser.parse("(?) hidden-mod")
  #
  #   # Load-neutral
  #   dep5 = parser.parse("~ neutral-mod")
  class MODDependencyParser
    # Parse a dependency string into a MODDependency object
    #
    # @param dependency_string [String] Dependency string to parse
    # @return [MODDependency] Parsed dependency object
    # @raise [ArgumentError] if the dependency string is invalid
    def parse(dependency_string)
      raise ArgumentError, "dependency_string cannot be nil or empty" if dependency_string.nil? || dependency_string.empty?

      type = determine_type(dependency_string)
      clean_string = remove_prefix(dependency_string, type)
      mod_name, version_requirement = parse_mod_name_and_version(clean_string)

      MODDependency.new(
        mod_name:,
        type:,
        version_requirement:
      )
    end

    private def determine_type(dependency_string)
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

    # Remove the prefix from the dependency string
    #
    # @param dependency_string [String] Dependency string
    # @param type [Symbol] Dependency type
    # @return [String] String with prefix removed and whitespace trimmed
    private def remove_prefix(dependency_string, type)
      case type
      when MODDependency::HIDDEN_OPTIONAL
        dependency_string[3..].strip
      when MODDependency::INCOMPATIBLE, MODDependency::OPTIONAL, MODDependency::LOAD_NEUTRAL
        dependency_string[1..].strip
      else
        dependency_string.strip
      end
    end

    # Parse mod name and optional version requirement
    #
    # @param clean_string [String] String with prefix removed
    # @return [Array<String, Types::MODVersionRequirement, nil>] Mod name and optional version requirement
    # @raise [ArgumentError] if the string format is invalid
    private def parse_mod_name_and_version(clean_string)
      # Valid operators in order of length (longest first to avoid partial matches)
      operators = [">=", "<=", ">", "<", "="]

      # Find the first operator in the string
      operator_match = nil
      operator_index = nil

      operators.each do |op|
        index = clean_string.index(" #{op} ")
        if index && (operator_index.nil? || index < operator_index)
          operator_match = op
          operator_index = index
        end
      end

      if operator_index.nil?
        # No version requirement
        mod_name = clean_string.strip

        # Check if string starts with an operator (invalid format)
        operators.each do |op|
          raise ArgumentError, "Invalid dependency format: empty mod name" if clean_string.strip.start_with?(op)

          # Check if string ends with an operator followed by whitespace (invalid format)
          if clean_string.rstrip.end_with?(op)
            raise ArgumentError, "Invalid dependency format: empty version"
          end
        end

        [mod_name, nil]
      else
        # Extract mod name and version
        mod_name = clean_string[0...operator_index].strip
        version_string = clean_string[(operator_index + operator_match.length + 2)..].strip

        raise ArgumentError, "Invalid dependency format: empty mod name" if mod_name.empty?
        raise ArgumentError, "Invalid dependency format: empty version" if version_string.empty?

        begin
          version = Types::MODVersion.from_string(version_string)
          requirement = Types::MODVersionRequirement.new(operator: operator_match, version:)
          [mod_name, requirement]
        rescue ArgumentError => e
          raise ArgumentError, "Invalid version requirement: #{e.message}"
        end
      end
    end
  end
end
