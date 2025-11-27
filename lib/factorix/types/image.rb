# frozen_string_literal: true

require "uri"

module Factorix
  module Types
    Image = Data.define(:id, :thumbnail, :url)

    # Image object from MOD Portal API
    #
    # Represents a MOD screenshot or image
    #
    # @see https://wiki.factorio.com/Mod_portal_API
    class Image
      # @!attribute [r] id
      #   @return [String] image ID
      # @!attribute [r] thumbnail
      #   @return [URI::HTTPS] thumbnail URL
      # @!attribute [r] url
      #   @return [URI::HTTPS] full-size image URL

      # Create Image from API response hash
      #
      # @param id [String] image ID
      # @param thumbnail [String] thumbnail URL
      # @param url [String] full-size image URL
      # @return [Image] new Image instance
      def initialize(id:, thumbnail:, url:)
        thumbnail = URI(thumbnail)
        url = URI(url)
        super
      end
    end
  end
end
