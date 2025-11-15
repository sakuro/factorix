# frozen_string_literal: true

require "json"
require "zip"

module Factorix
  module Types
    # Factorio mod info.json representation
    #
    # Represents the metadata file that must be present in every Factorio mod.
    # Only required fields (name, version, title, author) are enforced.
    #
    # @see https://lua-api.factorio.com/latest/auxiliary/mod-structure.html
    InfoJSON = Data.define(
      :name,
      :version,
      :title,
      :author,
      :description,
      :factorio_version,
      :dependencies
    ) {
      # Parse info.json from JSON string
      #
      # @param json_string [String] JSON content
      # @return [InfoJSON] parsed info.json
      # @raise [ArgumentError] if required fields are missing
      def self.from_json(json_string)
        data = JSON.parse(json_string)
        from_hash(data)
      rescue JSON::ParserError => e
        raise ArgumentError, "Invalid JSON: #{e.message}"
      end

      # Create InfoJSON from hash
      #
      # @param data [Hash] hash containing info.json fields
      # @return [InfoJSON] new instance
      # @raise [ArgumentError] if required fields are missing
      def self.from_hash(data)
        # Validate required fields
        required_fields = %w[name version title author]
        missing = required_fields - data.keys
        raise ArgumentError, "Missing required fields: #{missing.join(", ")}" unless missing.empty?

        # Parse dependencies
        parser = MODDependencyParser.new
        dependencies = (data["dependencies"] || []).map {|dep_str| parser.parse(dep_str) }

        new(
          name: data["name"],
          version: MODVersion.from_string(data["version"]),
          title: data["title"],
          author: data["author"],
          description: data["description"] || "",
          factorio_version: data["factorio_version"],
          dependencies:
        )
      end

      # Extract from zip file
      #
      # @param zip_path [Pathname, String] path to mod zip file
      # @return [InfoJSON] parsed info.json from zip
      # @raise [ArgumentError] if zip is invalid or info.json not found
      def self.from_zip(zip_path)
        Zip::File.open(zip_path) do |zip_file|
          # Find info.json (should be in top-level directory inside zip)
          info_entry = zip_file.find {|entry| entry.name.end_with?("/info.json") }
          raise ArgumentError, "info.json not found in #{zip_path}" unless info_entry

          json_string = info_entry.get_input_stream.read
          from_json(json_string)
        end
      rescue Zip::Error => e
        raise ArgumentError, "Invalid zip file: #{e.message}"
      end
    }
  end
end
