# frozen_string_literal: true

require "json"

module Factorix
  class MODSettings
    # Converter for MODSettings to/from JSON format
    class JSONConverter
      # Convert MODSettings to JSON string
      #
      # @param settings [Factorix::MODSettings] The MOD settings to convert
      # @return [String] JSON representation of the settings
      def convert_to(settings)
        data = build_hash(settings)
        JSON.pretty_generate(data)
      end

      # Convert JSON string to MODSettings
      #
      # @param json_string [String] The JSON string to parse
      # @return [Factorix::MODSettings] The parsed MOD settings
      def convert_from(json_string)
        data = JSON.parse(json_string)
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

      # Convert value for JSON output (handle SignedInteger/UnsignedInteger)
      #
      # @param value [Object] The value to convert
      # @return [Object] Converted value
      private def convert_value_for_output(value)
        case value
        when Types::SignedInteger, Types::UnsignedInteger
          # Integer(...) does not accept Integer instance
          Integer(value.to_s, 10)
        else
          value
        end
      end

      # Build MODSettings from parsed JSON data
      #
      # @param data [Hash] Parsed JSON data
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

      # Convert value from JSON input (detect integer types)
      #
      # @param value [Object] The value to convert
      # @return [Object] Converted value
      # @note Factorio mod settings use signed integers for int-setting type.
      #       Since JSON doesn't preserve signed/unsigned distinction,
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
