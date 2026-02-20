# frozen_string_literal: true

require "parslet"

module Factorix
  # Parser and writer for Factorio MOD changelog.txt files
  #
  # @see https://wiki.factorio.com/Tutorial:Mod_changelog_format
  class Changelog
    SEPARATOR = ("-" * 99).freeze
    public_constant :SEPARATOR

    UNRELEASED = "Unreleased"
    public_constant :UNRELEASED

    Section = Data.define(:version, :date, :categories)
    private_class_method :new

    # Load a changelog from a file
    #
    # @param path [Pathname] path to changelog.txt
    # @return [Changelog]
    # @raise [ChangelogParseError] if the file content is malformed
    def self.load(path)
      return new([]) unless path.exist?

      parse(path.read)
    end

    # Parse changelog text content
    #
    # @param text [String] changelog content
    # @return [Changelog]
    # @raise [ChangelogParseError] if the content is malformed
    def self.parse(text)
      tree = Grammar.new.parse(text)
      sections = Transform.new.apply(tree)
      new(Array(sections))
    rescue Parslet::ParseFailed => e
      raise ChangelogParseError, e.message
    end

    # @param sections [Array<Section>] changelog sections
    def initialize(sections)
      @sections = sections
    end

    # @return [Array<Section>]
    attr_reader :sections

    # Save the changelog to a file
    #
    # @param path [Pathname] path to write
    # @return [void]
    def save(path)
      path.write(to_s)
    end

    # Add an entry to the changelog
    #
    # @param version [MODVersion, String] target version (or Changelog::UNRELEASED)
    # @param category [String] category name
    # @param entry [String] entry text
    # @return [void]
    # @raise [InvalidArgumentError] if the entry already exists
    def add_entry(version, category, entry)
      section = find_or_create_section(version)
      entries = (section.categories[category] ||= [])
      raise InvalidArgumentError, "duplicate entry: #{entry}" if entries.include?(entry)

      entries << entry
    end

    # Replace the first section (Unreleased) with a versioned section
    # @param version [MODVersion] target version
    # @param date [String] release date (YYYY-MM-DD)
    # @return [void]
    def release_section(version, date:)
      raise InvalidOperationError, "First section is not Unreleased" unless @sections.first&.version == UNRELEASED
      raise InvalidOperationError, "Version #{version} already exists" if @sections.any? {|s| s.version == version }

      unreleased = @sections.first
      @sections[0] = Section[version:, date:, categories: unreleased.categories]
    end

    # Render the changelog as a string
    #
    # @return [String]
    def to_s
      @sections.map {|section| format_section(section) }.join("\n") + "\n"
    end

    private def find_or_create_section(version)
      @sections.find {|s| s.version == version } || create_section(version)
    end

    private def create_section(version)
      section = Section[version:, date: nil, categories: {}]
      @sections.unshift(section)
      section
    end

    private def format_section(section)
      lines = [SEPARATOR]
      lines << "Version: #{section.version}"
      lines << "Date: #{section.date}" if section.date
      section.categories.each do |cat, entries|
        lines << "  #{cat}:"
        entries.each do |entry|
          first, *rest = entry.split("\n")
          lines << "    - #{first}"
          rest.each {|line| lines << "      #{line}" }
        end
      end
      lines.join("\n")
    end

    # Parslet grammar for Factorio changelog.txt
    class Grammar < Parslet::Parser
      rule(:newline) { str("\r\n") | str("\n") }
      rule(:rest_of_line) { (newline.absent? >> any).repeat(1) }
      rule(:blank_line) { match[' \t'].repeat >> newline }

      rule(:separator) { str("-").repeat(99, 99) >> newline }

      rule(:version_line) { str("Version: ") >> rest_of_line.as(:version) >> newline }
      rule(:date_line) { str("Date: ") >> rest_of_line.as(:date) >> newline }

      # Category name: everything between "  " and ":\n", captured via negative lookahead
      rule(:category_line) { str("  ") >> ((str(":\n") | str(":\r\n")).absent? >> any).repeat(1).as(:category) >> str(":") >> newline }

      rule(:entry_first_line) { str("    - ") >> rest_of_line.as(:first) >> newline }
      rule(:continuation_line) { str("      ") >> rest_of_line >> newline }
      rule(:entry) { entry_first_line >> continuation_line.repeat.as(:rest) }

      rule(:category_block) { category_line >> entry.repeat(1).as(:entries) }

      rule(:section) do
        separator >>
          version_line >>
          date_line.maybe.as(:date_line) >>
          blank_line.repeat >>
          category_block.repeat.as(:categories) >>
          blank_line.repeat
      end

      rule(:changelog) { section.repeat(1).as(:sections) }

      root(:changelog)
    end
    private_constant :Grammar

    # Transform parsed tree into Section objects
    class Transform < Parslet::Transform
      rule(first: simple(:first), rest: subtree(:rest)) do
        continuations = rest.is_a?(Array) ? rest : [rest]
        parts = [first.to_s]
        continuations.each {|c| parts << c.to_s.delete_prefix("      ") if c.is_a?(Parslet::Slice) }
        parts.join("\n")
      end

      rule(category: simple(:cat), entries: subtree(:entries)) do
        entry_list = entries.is_a?(Array) ? entries : [entries]
        {cat.to_s => entry_list}
      end

      rule(version: simple(:ver), date_line: subtree(:date_data), categories: subtree(:cats)) do
        ver_str = ver.to_s.strip
        version = ver_str.casecmp("unreleased").zero? ? UNRELEASED : MODVersion.from_string(ver_str)

        date = date_data.is_a?(Hash) ? date_data[:date].to_s.strip : nil

        categories = {}
        cat_list = cats.is_a?(Array) ? cats : [cats]
        cat_list.each do |cat_hash|
          next unless cat_hash.is_a?(Hash)

          categories.merge!(cat_hash)
        end

        Section[version:, date:, categories:]
      end

      rule(sections: subtree(:secs)) do
        secs.is_a?(Array) ? secs : [secs]
      end
    end
    private_constant :Transform
  end
end
