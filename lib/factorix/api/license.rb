# frozen_string_literal: true

require "uri"

module Factorix
  module API
    License = Data.define(:id, :name, :title, :description, :url)

    # License object from MOD Portal API
    #
    # Represents a MOD license information.
    # Also provides valid license identifiers for edit_details API.
    #
    # @see https://wiki.factorio.com/Mod_portal_API
    # @see https://wiki.factorio.com/Mod_details_API
    class License
      # @!attribute [r] id
      #   @return [String] license ID
      # @!attribute [r] name
      #   @return [String] license name
      # @!attribute [r] title
      #   @return [String] license title
      # @!attribute [r] description
      #   @return [String] license description (long text)
      # @!attribute [r] url
      #   @return [URI::HTTPS] license URL

      # Valid license identifiers for edit_details API
      # Custom licenses (custom_$ID) are not included
      IDENTIFIERS = {
        "default_mit" => "MIT",
        "default_gnugplv3" => "GNU GPLv3",
        "default_gnulgplv3" => "GNU LGPLv3",
        "default_mozilla2" => "Mozilla Public License 2.0",
        "default_apache2" => "Apache License 2.0",
        "default_unlicense" => "The Unlicense"
      }.freeze
      private_constant :IDENTIFIERS

      # Pattern for custom license identifiers (custom_ + 24 lowercase hex chars)
      CUSTOM_LICENSE_PATTERN = /\Acustom_[0-9a-f]{24}\z/
      private_constant :CUSTOM_LICENSE_PATTERN

      # Check if the given value is a valid license identifier
      #
      # @param value [String] license identifier
      # @return [Boolean] true if valid (standard or custom license)
      def self.valid_identifier?(value)
        IDENTIFIERS.key?(value) || CUSTOM_LICENSE_PATTERN.match?(value)
      end

      # List all valid license identifier values
      #
      # @return [Array<String>] array of license identifiers
      def self.identifier_values = IDENTIFIERS.keys

      # Create License from API response hash
      #
      # @param id [String] license ID
      # @param name [String] license name
      # @param title [String] license title
      # @param description [String] license description
      # @param url [String] license URL
      # @return [License] new License instance
      def initialize(id:, name:, title:, description:, url:)
        url = URI(url)
        super
      end
    end
  end
end
