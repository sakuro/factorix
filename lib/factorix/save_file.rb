# frozen_string_literal: true

require "zip"
require "zlib"

module Factorix
  SaveFile = Data.define(:version, :mods, :startup_settings)

  # Data structure for Factorio save file information
  #
  # SaveFile provides functionality to extract MOD information and startup settings
  # from Factorio save files (.zip format containing level.dat0 or level-init.dat).
  #
  # @!attribute [r] version
  #   @return [Factorix::GameVersion] Game version from the save file
  # @!attribute [r] mods
  #   @return [Hash<String, Factorix::MODState>] Hash of MOD name to MODState
  # @!attribute [r] startup_settings
  #   @return [Factorix::MODSettings::Section] Startup settings section
  class SaveFile
    # Level file names to search for, in priority order
    LEVEL_FILE_NAMES = %w[level.dat0 level-init.dat].freeze
    private_constant :LEVEL_FILE_NAMES

    # Load a save file and extract MOD information and settings
    #
    # @param path [Pathname] Path to the save file (.zip)
    # @return [SaveFile] Extracted save file data
    # @raise [Errno::ENOENT] If save file or level file not found
    # @raise [Factorix::Error] If save file format is invalid
    def self.load(path) = Parser.new(path).parse

    # Internal parser for save files
    class Parser
      # Initialize a new Parser instance
      #
      # @param path [Pathname] Path to the save file
      def initialize(path) = @path = path

      # Parse the save file and return extracted data
      #
      # @return [SaveFile] Extracted save file data
      # @raise [Errno::ENOENT] If save file or level file not found
      def parse
        open_level_file do |stream|
          deserializer = SerDes::Deserializer.new(stream)
          parse_save_header(deserializer)
          skip_unknown_bytes(deserializer)
          parse_startup_settings(deserializer)
        end

        SaveFile.new(version: @version, mods: @mods, startup_settings: @startup_settings)
      end

      private def open_level_file
        Zip::File.open(@path) do |zip_file|
          LEVEL_FILE_NAMES.each do |file_name|
            entry = find_level_entry(zip_file, file_name)
            next unless entry

            stream = entry.get_input_stream
            return yield decompress_if_needed(stream)
          end

          raise Errno::ENOENT, "level.dat0 or level-init.dat not found in #{@path}"
        end
      end

      # Find a level file entry in the zip file
      #
      # @param zip_file [Zip::File] The zip file
      # @param file_name [String] The level file name to search for
      # @return [Zip::Entry, nil] The entry if found, nil otherwise
      private def find_level_entry(zip_file, file_name) = zip_file.glob("*/#{file_name}").first

      # Decompress stream if it's zlib compressed
      #
      # @param stream [IO] The input stream
      # @return [IO] Decompressed stream or original stream
      private def decompress_if_needed(stream)
        # Read CMF (Compression Method and Flags) byte
        cmf = stream.read(1)
        return StringIO.new("") if cmf.nil?

        stream.rewind

        # CMF = 0x78 indicates zlib compression (DEFLATE with 32K window)
        if cmf.unpack1("C") == 0x78
          StringIO.new(Zlib::Inflate.inflate(stream.read))
        else
          stream
        end
      end

      # Parse save header to extract game version and MOD list
      #
      # @param deserializer [Factorix::SerDes::Deserializer] The deserializer
      # @return [void]
      private def parse_save_header(deserializer)
        # Read game version
        @version = deserializer.read_game_version

        # Skip 1 byte after version
        deserializer.read_u8

        # Skip fields we don't need
        deserializer.read_str  # campaign
        deserializer.read_str  # level_name
        deserializer.read_str  # base_mod
        deserializer.read_u8   # difficulty
        deserializer.read_bool # finished
        deserializer.read_bool # player_won
        deserializer.read_str  # next_level
        deserializer.read_bool # can_continue
        deserializer.read_bool # finished_but_continuing
        deserializer.read_bool # saving_replay
        deserializer.read_bool # allow_non_admin_debug_options
        deserializer.read_mod_version # loaded_from (MODVersion, not GameVersion)
        deserializer.read_u16 # loaded_from_build
        deserializer.read_u8 # allowed_commands

        # Additional fields before the MOD list
        # These fields' purposes are not yet fully understood
        deserializer.read_bool  # Unknown boolean field
        deserializer.read_u32   # Unknown u32 field
        deserializer.read_bool  # Unknown boolean field

        # Read MOD list
        parse_mods(deserializer)
      end

      # Parse MOD list from save header
      #
      # @param deserializer [Factorix::SerDes::Deserializer] The deserializer
      # @return [void]
      private def parse_mods(deserializer)
        mods_count = deserializer.read_optim_u32
        @mods = {}

        mods_count.times do
          name = deserializer.read_str
          version = deserializer.read_mod_version
          _crc = deserializer.read_u32

          # All MODs in save file are enabled
          @mods[name] = MODState.new(enabled: true, version:)
        end
      end

      # Skip unknown 4 bytes after MOD list
      #
      # @param deserializer [Factorix::SerDes::Deserializer] The deserializer
      # @return [void]
      private def skip_unknown_bytes(deserializer) = deserializer.read_bytes(4)

      # Parse startup settings from save file
      #
      # @param deserializer [Factorix::SerDes::Deserializer] The deserializer
      # @return [void]
      private def parse_startup_settings(deserializer)
        raw_settings = deserializer.read_property_tree

        # Create a new Section and populate it
        @startup_settings = MODSettings::Section.new("startup")

        return unless raw_settings.is_a?(Hash)

        raw_settings.each do |key, value_hash|
          # Extract the actual value from the {"value" => X} hash
          next unless value_hash.is_a?(Hash)

          @startup_settings[key] = value_hash["value"]
        end
      end
    end
    private_constant :Parser
  end
end
