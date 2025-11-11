# frozen_string_literal: true

require "parslet"

module Factorix
  # Parser for MOD dependency strings using Parslet
  #
  # This class parses dependency strings from info.json files and converts them
  # into MODDependency objects using a PEG-based parser.
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
    # Parslet grammar for dependency strings
    class Grammar < Parslet::Parser
      rule(:space) { match['\s'].repeat(1) }
      rule(:space?) { space.maybe }

      # Prefix rules (longest first to avoid partial matches)
      rule(:prefix) do
        str("(?)").as(:hidden_optional) |
          str("!").as(:incompatible) |
          str("?").as(:optional) |
          str("~").as(:load_neutral)
      end

      # Mod name: alphanumeric, dash, underscore
      rule(:mod_name) { match["a-zA-Z0-9_-"].repeat(1).as(:mod_name) }

      # Version operators (longest first)
      rule(:operator) do
        (str(">=") | str("<=") | str(">") | str("<") | str("=")).as(:operator)
      end

      # Version: X.Y.Z format
      rule(:version) do
        (match["0-9"].repeat(1) >> str(".") >> match["0-9"].repeat(1) >> str(".") >> match["0-9"].repeat(1)).as(:version)
      end

      # Version requirement: operator space version
      rule(:version_requirement) do
        space >> operator >> space >> version
      end

      # Complete dependency: [prefix] [space] mod_name [version_requirement]
      rule(:dependency) do
        space? >>
          prefix.maybe.as(:prefix) >>
          space? >>
          mod_name >>
          version_requirement.maybe.as(:requirement) >>
          space?
      end

      root(:dependency)
    end

    # Transform parsed tree into structured data
    class Transform < Parslet::Transform
      rule(mod_name: simple(:name)) { {mod_name: name.to_s} }

      rule(version: simple(:ver)) { {version: ver.to_s} }

      rule(operator: simple(:op), version: simple(:ver)) do
        {operator: op.to_s, version: ver.to_s}
      end

      rule(optional: simple(:_)) { {type: MODDependency::OPTIONAL} }
      rule(hidden_optional: simple(:_)) { {type: MODDependency::HIDDEN_OPTIONAL} }
      rule(incompatible: simple(:_)) { {type: MODDependency::INCOMPATIBLE} }
      rule(load_neutral: simple(:_)) { {type: MODDependency::LOAD_NEUTRAL} }
    end

    def initialize
      @grammar = Grammar.new
      @transform = Transform.new
    end

    # Parse a dependency string into a MODDependency object
    #
    # @param dependency_string [String] Dependency string to parse
    # @return [MODDependency] Parsed dependency object
    # @raise [ArgumentError] if the dependency string is invalid
    def parse(dependency_string)
      raise ArgumentError, "dependency_string cannot be nil or empty" if dependency_string.nil? || dependency_string.empty?

      begin
        tree = @grammar.parse(dependency_string)
        data = @transform.apply(tree)

        # Extract values from parsed data
        mod_name = data[:mod_name]
        type = data.dig(:prefix, :type) || MODDependency::REQUIRED
        version_requirement = build_version_requirement(data[:requirement])

        MODDependency.new(
          mod_name:,
          type:,
          version_requirement:
        )
      rescue Parslet::ParseFailed => e
        raise ArgumentError, parse_error_message(dependency_string, e)
      end
    end

    private def build_version_requirement(requirement_data)
      return nil if requirement_data.nil? || requirement_data.empty?

      operator = requirement_data[:operator]
      version_string = requirement_data[:version]

      version = Types::MODVersion.from_string(version_string)
      Types::MODVersionRequirement.new(operator:, version:)
    rescue ArgumentError => e
      raise ArgumentError, "Invalid version requirement: #{e.message}"
    end

    private def parse_error_message(input, error)
      # Check for common error patterns
      if input.strip.match?(/^[><=]+/)
        "Invalid dependency format: empty mod name"
      elsif input.match?(/[><=]\s*$/)
        "Invalid dependency format: empty version"
      elsif input.match?(/[><=]\s+\S+$/) && !input.match?(/[><=]\s+\d+\.\d+\.\d+/)
        "Invalid version requirement: invalid version format"
      else
        "Invalid dependency format: #{error.parse_failure_cause.ascii_tree}"
      end
    end
  end
end
