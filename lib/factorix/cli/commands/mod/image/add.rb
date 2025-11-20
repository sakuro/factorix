# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        module Image
          # Add an image to a MOD on Factorio MOD Portal
          class Add < Base
            # @!parse
            #   # @return [Portal]
            #   attr_reader :portal
            include Factorix::Import[:portal]

            desc "Add an image to a MOD"

            argument :mod_name, type: :string, required: true, desc: "MOD name"
            argument :image_file, type: :string, required: true, desc: "Path to image file"

            # Execute the add command
            #
            # @param mod_name [String] the mod name
            # @param image_file [String] path to image file
            # @return [void]
            def call(mod_name:, image_file:, **)
              file_path = Pathname(image_file)

              raise ArgumentError, "Image file not found: #{image_file}" unless file_path.exist?

              # Add image via Portal
              image = portal.add_mod_image(mod_name, file_path)

              say "Image added successfully!"
              say "  ID: #{image.id}"
              say "  Thumbnail: #{image.thumbnail}"
              say "  Full URL: #{image.url}"
            end
          end
        end
      end
    end
  end
end
