# frozen_string_literal: true

require "base64"
require "json"
require "zlib"

module Factorix
  # Represents a Factorio blueprint
  #
  # A blueprint string has the format: version_byte + Base64(zlib(JSON))
  # Only version byte '0' is supported.
  class Blueprint
    # The only supported version byte
    SUPPORTED_VERSION = "0"
    private_constant :SUPPORTED_VERSION

    # @return [Hash] The blueprint data
    attr_reader :data

    # Decode a blueprint string into a Blueprint
    #
    # @param string [String] The blueprint string
    # @return [Blueprint]
    # @raise [UnsupportedBlueprintVersionError] if the version byte is not '0'
    # @raise [BlueprintFormatError] if the string is not a valid blueprint
    def self.decode(string)
      version = string[0]
      raise UnsupportedBlueprintVersionError, "Unsupported blueprint version: #{version.inspect}" unless version == SUPPORTED_VERSION

      compressed = Base64.strict_decode64(string[1..])
      json_string = Zlib::Inflate.inflate(compressed)
      new(JSON.parse(json_string))
    rescue ArgumentError => e
      raise BlueprintFormatError, "Invalid Base64 encoding: #{e.message}"
    rescue Zlib::Error => e
      raise BlueprintFormatError, "Invalid zlib data: #{e.message}"
    rescue JSON::ParserError => e
      raise BlueprintFormatError, "Invalid JSON: #{e.message}"
    end

    # @param data [Hash] The blueprint data
    def initialize(data)
      @data = data
    end

    # Encode this blueprint to a blueprint string
    #
    # @return [String]
    def encode
      json_string = JSON.generate(@data)
      compressed = Zlib::Deflate.deflate(json_string, Zlib::BEST_COMPRESSION)
      SUPPORTED_VERSION + Base64.strict_encode64(compressed)
    end

    # Serialize this blueprint to pretty-printed JSON
    #
    # @return [String]
    def to_json(*)
      JSON.pretty_generate(@data)
    end
  end
end
