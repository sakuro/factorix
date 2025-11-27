# frozen_string_literal: true

require "uri"

module Factorix
  module Types
    License = Data.define(:id, :name, :title, :description, :url)

    # License object from MOD Portal API
    #
    # Represents a MOD license information
    #
    # @see https://wiki.factorio.com/Mod_portal_API
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
