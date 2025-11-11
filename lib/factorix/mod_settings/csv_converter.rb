# frozen_string_literal: true

require "csv"

module Factorix
  class MODSettings
    # Converter for MODSettings to CSV format
    # Note: This converter only supports dump (convert_to), not load (convert_from)
    # because CSV format does not include game_version information
    class CSVConverter
      # Convert MODSettings to CSV string
      #
      # @param settings [Factorix::MODSettings] The MOD settings to convert
      # @return [String] CSV representation of the settings
      def convert_to(settings)
        CSV.generate do |csv|
          csv << %w[section name value]

          settings.each_section do |section|
            section.each do |key, value|
              csv << [section.name, key, convert_value_for_output(value)]
            end
          end
        end
      end

      # Convert CSV string to MODSettings
      #
      # @param _csv_string [String] The CSV string to parse
      # @return [Factorix::MODSettings] The parsed MOD settings
      # @raise [NotImplementedError] CSV format does not support restore operation
      def convert_from(_csv_string)
        raise NotImplementedError, "CSV format does not support restore operation"
      end

      private def convert_value_for_output(value)
        case value
        when Types::SignedInteger, Types::UnsignedInteger
          # Integer(...) does not accept Integer instance
          Integer(value.to_s, 10)
        else
          value
        end
      end
    end
  end
end
