# frozen_string_literal: true

require "json"
require "tempfile"
require "zip"

module Factorix
  module Types
    InfoJSON = Data.define(:name, :version, :title, :author, :description, :factorio_version, :dependencies)

    # Factorio mod info.json representation
    #
    # Represents the metadata file that must be present in every Factorio mod.
    # Only required fields (name, version, title, author) are enforced.
    #
    # @see https://lua-api.factorio.com/latest/auxiliary/mod-structure.html
    class InfoJSON
      # Parse info.json from JSON string
      #
      # @param json_string [String] JSON content
      # @return [InfoJSON] parsed info.json
      # @raise [ArgumentError] if required fields are missing or JSON is invalid
      def self.from_json(json_string)
        data = JSON.parse(json_string)

        # Validate required fields
        required_fields = %w[name version title author]
        missing = required_fields - data.keys
        raise ArgumentError, "Missing required fields: #{missing.join(", ")}" unless missing.empty?

        # Parse dependencies
        parser = Dependency::Parser.new
        dependencies = (data["dependencies"] || []).map {|dep_str| parser.parse(dep_str) }

        new(name: data["name"], version: MODVersion.from_string(data["version"]), title: data["title"], author: data["author"], description: data["description"] || "", factorio_version: data["factorio_version"], dependencies:)
      rescue JSON::ParserError => e
        raise ArgumentError, "Invalid JSON: #{e.message}"
      end

      # Extract from zip file
      #
      # Uses caching to avoid repeated ZIP extraction for the same file.
      # Cache key is based on file path (MOD ZIPs are immutable after download).
      #
      # @param zip_path [Pathname] path to mod zip file
      # @return [InfoJSON] parsed info.json from zip
      # @raise [ArgumentError] if zip is invalid or info.json not found
      def self.from_zip(zip_path)
        cache = Application.resolve(:info_json_cache)
        logger = Application.resolve(:logger)
        cache_key = cache.key_for(zip_path.to_s)

        # Try to read from cache
        if (cached_json = cache.read(cache_key, encoding: Encoding::UTF_8))
          logger.debug("info.json cache hit", path: zip_path.to_s)
          return from_json(cached_json)
        end

        logger.debug("info.json cache miss", path: zip_path.to_s)

        # Extract from ZIP
        json_string = Zip::File.open(zip_path) {|zip_file|
          info_entry = zip_file.find {|entry| entry.name.end_with?("/info.json") }
          raise ArgumentError, "info.json not found in #{zip_path}" unless info_entry

          info_entry.get_input_stream.read
        }

        # Store in cache
        temp_file = Tempfile.new("info_json_cache")
        begin
          temp_file.write(json_string)
          temp_file.close
          cache.store(cache_key, Pathname(temp_file.path))
          logger.debug("Stored info.json in cache", path: zip_path.to_s)
        ensure
          temp_file.unlink
        end

        from_json(json_string)
      rescue Zip::Error => e
        raise ArgumentError, "Invalid zip file: #{e.message}"
      end
    end
  end
end
