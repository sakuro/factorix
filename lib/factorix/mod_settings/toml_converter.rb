# frozen_string_literal: true

require "perfect_toml"

module Factorix
  class MODSettings
    # Converter for MODSettings to/from TOML format
    class TOMLConverter
      # Convert MODSettings to TOML string
      #
      # @param settings [Factorix::MODSettings] The MOD settings to convert
      # @return [String] TOML representation of the settings
      def convert_to(settings)
        data = build_hash(settings)
        PerfectTOML.generate(data)
      end

      # Convert TOML string to MODSettings
      #
      # @param toml_string [String] The TOML string to parse
      # @return [Factorix::MODSettings] The parsed MOD settings
      def convert_from(toml_string)
        data = PerfectTOML.parse(toml_string)
        build_settings(data)
      end

      private def build_hash(settings)
        result = {
          "game_version" => settings.game_version.to_s
        }

        settings.each_section do |section|
          section_hash = {}
          section.each do |key, value|
            section_hash[key] = convert_value_for_output(value)
          end
          result[section.name] = section_hash unless section_hash.empty?
        end

        result
      end

      # Convert value for TOML output (handle SignedInteger/UnsignedInteger)
      #
      # @param value [Object] The value to convert
      # @return [Object] Converted value
      private def convert_value_for_output(value)
        case value
        when Types::SignedInteger, Types::UnsignedInteger
          Integer(value.to_s, 10)
        else
          value
        end
      end

      # Build MODSettings from parsed TOML data
      #
      # @param data [Hash] Parsed TOML data
      # @return [Factorix::MODSettings] The MOD settings
      private def build_settings(data)
        game_version = Types::GameVersion.from_string(data["game_version"])
        sections = {}

        MODSettings::VALID_SECTIONS.each do |section_name|
          section = Section.new(section_name)
          if data.key?(section_name)
            data[section_name].each do |key, value|
              section[key] = convert_value_for_input(value)
            end
          end
          sections[section_name] = section
        end

        MODSettings.new(game_version, sections)
      end

      # Convert value from TOML input (detect integer types)
      #
      # @param value [Object] The value to convert
      # @return [Object] Converted value
      # @note Factorio mod settings use signed integers for int-setting type.
      #       Since TOML doesn't preserve signed/unsigned distinction,
      #       we use SignedInteger for all integer values.
      # @see https://wiki.factorio.com/Tutorial:Mod_settings#int-setting
      private def convert_value_for_input(value)
        case value
        when Integer
          Types::SignedInteger.new(value)
        else
          value
        end
      end
    end
  end
end
