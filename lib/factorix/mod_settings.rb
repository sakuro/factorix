# frozen_string_literal: true

module Factorix
  # Class for handling MOD settings
  class ModSettings
    # Valid section names
    VALID_SECTIONS = %w[startup runtime-global runtime-per-user].freeze
    private_constant :VALID_SECTIONS

    # Represents a section in mod settings
    class Section
      include Enumerable
      # @param name [String] The section name
      # @raise [InvalidModSectionError] If the section name is invalid
      def initialize(name)
        unless VALID_SECTIONS.include?(name)
          raise InvalidModSectionError, "Invalid mod section name: #{name}"
        end

        @name = name
        @settings = {}
      end

      # @return [String] The section name
      attr_reader :name

      # Set a setting value
      # @param key [String] The setting key
      # @param value [Object] The setting value
      # @return [Object] The setting value
      def []=(key, value)
        @settings[key] = value
      end

      # Get a setting value
      # @param key [String] The setting key
      # @return [Object, nil] The setting value or nil if not found
      def [](key)
        @settings[key]
      end

      # Iterate over settings
      # @yield [key, value] Block to be called for each setting
      # @yieldparam key [String] The setting key
      # @yieldparam value [Object] The setting value
      # @return [Enumerator] If no block is given
      def each
        return @settings.to_enum(:each) unless block_given?

        @settings.each {|k, v| yield(k, v) }
      end

      # @return [Boolean] True if the section has no settings
      def empty?
        @settings.empty?
      end
    end

    # Create a new ModSettings instance and load settings from file
    # @param path [Pathname] Path to the mod settings file
    def initialize(path)
      @sections = {}
      load_settings(path)
    end

    # Get a section by name
    # @param name [String] The section name
    # @return [Section] The section
    # @raise [InvalidModSectionError] If the section name is invalid
    # @raise [ModSectionNotFoundError] If the section is not found
    def [](name)
      unless VALID_SECTIONS.include?(name)
        raise InvalidModSectionError, "Invalid mod section name: #{name}"
      end

      section = @sections[name]
      unless section
        raise ModSectionNotFoundError, "Mod section not found: #{name}"
      end

      section
    end

    # Iterate over sections
    # @yield [section] Block to be called for each section
    # @yieldparam section [Section] The section
    # @return [Enumerator] If no block is given
    def each_section
      return @sections.values.to_enum(:each) unless block_given?

      @sections.each_value {|section| yield(section) }
    end

    # Load settings from file
    # @param path [Pathname] Path to the mod settings file
    # @return [void]
    private def load_settings(path)
      path.open("rb") do |file|
        deserializer = Factorix::SerDes::Deserializer.new(file)

        # 1. Read version64
        deserializer.read_version64

        # 2. Skip a boolean value
        deserializer.read_bool

        # 3. Read property tree and organize into sections
        raw_settings = deserializer.read_property_tree
        organize_into_sections(raw_settings)
      end
    end

    # Organize raw settings into sections
    # @param raw_settings [Hash] Raw settings from deserializer
    # @return [void]
    # @raise [InvalidModSectionError] If an invalid section name is encountered
    private def organize_into_sections(raw_settings)
      process_raw_settings(raw_settings)
      ensure_all_sections_exist
    end

    # Process raw settings and add them to sections
    # @param raw_settings [Hash] Raw settings from deserializer
    # @return [void]
    # @raise [InvalidModSectionError] If an invalid section name is encountered
    private def process_raw_settings(raw_settings)
      raw_settings.each do |section_name, section_settings|
        unless VALID_SECTIONS.include?(section_name)
          raise InvalidModSectionError, "Invalid mod section name: #{section_name}"
        end

        section = @sections[section_name] ||= Section.new(section_name)
        add_settings_to_section(section, section_settings)
      end
    end

    # Add settings to a section
    # @param section [Section] The section to add settings to
    # @param section_settings [Hash] The settings to add
    # @return [void]
    private def add_settings_to_section(section, section_settings)
      section_settings.each do |key, value_hash|
        # Extract the actual value from the {"value" => X} hash
        section[key] = value_hash["value"]
      end
    end

    # Ensure all valid sections exist, even if empty
    # @return [void]
    private def ensure_all_sections_exist
      VALID_SECTIONS.each do |section_name|
        @sections[section_name] ||= Section.new(section_name)
      end
    end
  end
end
