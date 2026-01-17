# frozen_string_literal: true

require "parslet"

module Factorix
  module Dependency
    # Parser for MOD dependency strings using Parslet
    #
    # This class parses dependency strings from info.json files and converts them
    # into Dependency::Entry objects using a PEG-based parser.
    #
    # @example Parsing various dependency formats
    #   parser = Dependency::Parser.new
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
    class Parser
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

        # MOD name: starts with alphanumeric, can contain spaces
        # Cannot start with operators or contain only operators
        rule(:mod_name_start) { match["a-zA-Z0-9_-"] }
        rule(:mod_name_char) { match["a-zA-Z0-9_-"] | (space >> match["a-zA-Z0-9_-"].repeat(1)) }
        rule(:mod_name) { (mod_name_start >> mod_name_char.repeat).as(:mod_name) }

        # Version operators (longest first)
        rule(:operator) do
          (str(">=") | str("<=") | str(">") | str("<") | str("=")).as(:operator)
        end

        # Version: X.Y.Z or X.Y format
        rule(:version) do
          (match["0-9"].repeat(1) >> str(".") >> match["0-9"].repeat(1) >> (str(".") >> match["0-9"].repeat(1)).maybe).as(:version)
        end

        # Version requirement: operator space version
        rule(:version_requirement) do
          space? >> operator >> space? >> version
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
        rule(mod_name: simple(:name)) { {mod_name: name.to_s.strip} }

        rule(version: simple(:ver)) { {version: ver.to_s} }

        rule(operator: simple(:op), version: simple(:ver)) do
          {operator: op.to_s, version: ver.to_s}
        end

        rule(optional: simple(:_)) { {type: Entry::OPTIONAL} }
        rule(hidden_optional: simple(:_)) { {type: Entry::HIDDEN_OPTIONAL} }
        rule(incompatible: simple(:_)) { {type: Entry::INCOMPATIBLE} }
        rule(load_neutral: simple(:_)) { {type: Entry::LOAD_NEUTRAL} }
      end

      def initialize
        @grammar = Grammar.new
        @transform = Transform.new
      end

      # Parse a dependency string into a Dependency::Entry object
      #
      # @param dependency_string [String] Dependency string to parse
      # @return [Entry] Parsed dependency object
      # @raise [DependencyParseError] if the dependency string is invalid
      def parse(dependency_string)
        raise DependencyParseError, "dependency_string cannot be nil or empty" if dependency_string.nil? || dependency_string.empty?

        begin
          tree = @grammar.parse(dependency_string)
          data = @transform.apply(tree)

          mod_name = data[:mod_name].to_s
          mod = MOD[name: mod_name]
          type = data.dig(:prefix, :type) || Entry::REQUIRED
          version_requirement = build_version_requirement(data[:requirement])

          Entry[mod:, type:, version_requirement:]
        rescue Parslet::ParseFailed => e
          raise DependencyParseError, parse_error_message(dependency_string, e)
        end
      end

      private def build_version_requirement(requirement_data)
        return nil if requirement_data.nil? || requirement_data.empty?

        operator = requirement_data[:operator]
        version_string = requirement_data[:version]

        version = MODVersion.from_string(version_string)
        MODVersionRequirement[operator:, version:]
      rescue VersionParseError => e
        # Skip version requirements with out-of-range version components
        Container[:logger].warn("Skipping version requirement '#{version_string}': #{e.message}")
        nil
      end

      private def parse_error_message(input, error)
        if input.strip.match?(/^[><=]+/)
          "Invalid dependency format: empty MOD name (input: #{input.inspect})"
        elsif input.match?(/[><=]\s*$/)
          "Invalid dependency format: empty version (input: #{input.inspect})"
        elsif input.match?(/[><=]\s+\S+$/) && !input.match?(/[><=]\s+\d+\.\d+\.\d+/)
          "Invalid version requirement: invalid version format (input: #{input.inspect})"
        else
          "Invalid dependency format (input: #{input.inspect}): #{error.parse_failure_cause.ascii_tree}"
        end
      end
    end
  end
end
