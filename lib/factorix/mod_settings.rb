# frozen_string_literal: true

module Factorix
  # Class for handling MOD settings
  #
  # MODSettings manages the settings from mod-settings.dat file, which contains
  # three sections: startup, runtime-global, and runtime-per-user.
  class MODSettings
    # Valid section names
    VALID_SECTIONS = %w[startup runtime-global runtime-per-user].freeze
    public_constant :VALID_SECTIONS

    # Represents a section in MOD settings
    class Section
      include Enumerable

      # Initialize a new section with the given name
      #
      # @param name [String] The section name
      # @raise [ArgumentError] If the section name is invalid
      def initialize(name)
        unless VALID_SECTIONS.include?(name)
          raise ArgumentError, "Invalid MOD section name: #{name}"
        end

        @name = name
        @settings = {}
      end

      # Get the section name
      #
      # @return [String] The section name
      attr_reader :name

      # Set a setting value in this section
      #
      # @param key [String] The setting key
      # @param value [Object] The setting value
      # @return [Object] The setting value
      def []=(key, value)
        @settings[key] = value
      end

      # Get a setting value from this section
      #
      # @param key [String] The setting key
      # @return [Object, nil] The setting value or nil if not found
      def [](key) = @settings[key]

      # Iterate over all settings in this section
      #
      # @yield [key, value] Block to be called for each setting
      # @yieldparam key [String] The setting key
      # @yieldparam value [Object] The setting value
      # @return [Enumerator] If no block is given
      def each(&)
        return @settings.to_enum(:each) unless block_given?

        @settings.each(&)
      end

      # Check if this section has any settings
      #
      # @return [Boolean] True if the section has no settings
      def empty? = @settings.empty?

      # Check if a key exists in this section
      #
      # @param key [String] The setting key
      # @return [Boolean] True if the key exists
      def key?(key) = @settings.key?(key)
      alias has_key? key?
      alias include? key?

      # Get all keys in this section
      #
      # @return [Array<String>] Array of all setting keys
      def keys = @settings.keys

      # Get all values in this section
      #
      # @return [Array<Object>] Array of all setting values
      def values = @settings.values

      # Get the number of settings in this section
      #
      # @return [Integer] Number of settings
      def size = @settings.size
      alias length size

      # Fetch a setting value with optional default or block
      #
      # @param key [String] The setting key
      # @param default [Object] Default value if key doesn't exist (optional)
      # @yield [key] Block to compute default value if key doesn't exist
      # @yieldparam key [String] The missing key
      # @return [Object] The setting value, default, or block result
      # @raise [KeyError] If key doesn't exist and no default/block provided
      def fetch(key, *, &) = @settings.fetch(key, *, &)

      # Convert this section to a Hash
      #
      # @return [Hash<String, Object>] Hash of all settings
      def to_h = @settings.dup
    end

    # Load MOD settings from file
    #
    # @param path [Pathname] Path to the MOD settings file (default: runtime.mod_settings_path)
    # @return [MODSettings] New MODSettings instance
    def self.load(path=Application[:runtime].mod_settings_path)
      path.open("rb") do |io|
        game_version, sections = load_settings_from_io(io)
        new(game_version, sections)
      end
    end

    # Load settings from IO object
    #
    # @param io [IO] IO object to read from
    # @return [Array<Factorix::GameVersion, Hash<String, Section>>] Game version and hash of sections
    def self.load_settings_from_io(io)
      deserializer = SerDes::Deserializer.new(io)

      # 1. Read version (GameVersion)
      game_version = deserializer.read_game_version

      # 2. Skip a boolean value
      deserializer.read_bool

      # 3. Read property tree and organize into sections
      raw_settings = deserializer.read_property_tree
      sections = organize_into_sections(raw_settings)

      # 4. Check for extra data at the end of file
      unless deserializer.eof?
        raise ExtraDataError, "Extra data found at the end of MOD settings file"
      end

      [game_version, sections]
    end
    private_class_method :load_settings_from_io

    # Organize raw settings data into appropriate sections
    #
    # @param raw_settings [Hash] Raw settings from deserializer
    # @return [Hash<String, Section>] Hash of sections
    # @raise [ArgumentError] If an invalid section name is encountered
    def self.organize_into_sections(raw_settings)
      sections = {}
      process_raw_settings(raw_settings, sections)
      ensure_all_sections_exist(sections)
      sections
    end
    private_class_method :organize_into_sections

    # Process raw settings and add them to their respective sections
    #
    # @param raw_settings [Hash] Raw settings from deserializer
    # @param sections [Hash<String, Section>] Hash to populate with sections
    # @return [void]
    # @raise [ArgumentError] If an invalid section name is encountered
    def self.process_raw_settings(raw_settings, sections)
      raw_settings.each do |section_name, section_settings|
        unless VALID_SECTIONS.include?(section_name)
          raise ArgumentError, "Invalid MOD section name: #{section_name}"
        end

        section = sections[section_name] ||= Section.new(section_name)
        add_settings_to_section(section, section_settings)
      end
    end
    private_class_method :process_raw_settings

    # Add the provided settings to the specified section
    #
    # @param section [Section] The section to add settings to
    # @param section_settings [Hash] The settings to add
    # @return [void]
    def self.add_settings_to_section(section, section_settings)
      section_settings.each do |key, value_hash|
        # Extract the actual value from the {"value" => X} hash
        section[key] = value_hash["value"]
      end
    end
    private_class_method :add_settings_to_section

    # Ensure all valid sections exist in the settings, creating empty ones if necessary
    #
    # @param sections [Hash<String, Section>] Hash to populate with sections
    # @return [void]
    def self.ensure_all_sections_exist(sections)
      VALID_SECTIONS.each do |section_name|
        sections[section_name] ||= Section.new(section_name)
      end
    end
    private_class_method :ensure_all_sections_exist

    # Create a new MODSettings instance
    #
    # @param game_version [Factorix::GameVersion] Game version
    # @param sections [Hash<String, Section>] Hash of section name to Section objects
    def initialize(game_version, sections)
      @game_version = game_version
      @sections = sections
    end

    # Get the game version
    #
    # @return [Factorix::GameVersion] Game version
    attr_reader :game_version

    # Get a section by name from the MOD settings
    #
    # @param name [String] The section name
    # @return [Section] The section
    # @raise [ArgumentError] If the section name is invalid
    # @raise [Factorix::MODSectionNotFoundError] If the section is not found
    def [](name)
      unless VALID_SECTIONS.include?(name)
        raise ArgumentError, "Invalid MOD section name: #{name}"
      end

      section = @sections[name]
      unless section
        raise MODSectionNotFoundError, "MOD section not found: #{name}"
      end

      section
    end

    # Iterate over all sections in the MOD settings
    #
    # @yield [section] Block to be called for each section
    # @yieldparam section [Section] The section
    # @return [Enumerator] If no block is given
    def each_section(&)
      return @sections.values.to_enum(:each) unless block_given?

      @sections.each_value(&)
    end

    # Save MOD settings to file
    #
    # @param path [Pathname] Path to save the MOD settings file (default: runtime.mod_settings_path)
    # @return [void]
    def save(path=Application[:runtime].mod_settings_path)
      path.open("wb") do |file|
        serializer = SerDes::Serializer.new(file)

        # 1. Write version
        serializer.write_game_version(@game_version)

        # 2. Write a boolean value (seems to be always false)
        serializer.write_bool(false)

        # 3. Write property tree
        settings_hash = build_settings_hash
        serializer.write_property_tree(settings_hash)
      end
    end

    # Build settings hash for serialization
    #
    # @return [Hash] Hash of settings organized by section
    private def build_settings_hash
      result = {}
      @sections.each do |section_name, section|
        section_hash = {}
        section.each do |key, value|
          section_hash[key] = {"value" => value}
        end
        result[section_name] = section_hash unless section_hash.empty?
      end
      result
    end
  end
end
