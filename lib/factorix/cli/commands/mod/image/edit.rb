# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        module Image
          # Edit MOD's image list on Factorio MOD Portal
          class Edit < Base
            # @!parse
            #   # @return [Portal]
            #   attr_reader :portal
            include Factorix::Import[:portal]

            desc "Edit MOD's image list (reorder/remove images)"

            argument :mod_name, type: :string, required: true, desc: "MOD name"
            argument :image_ids, type: :array, required: true, desc: "Image IDs in desired order"

            # Execute the edit command
            #
            # @param mod_name [String] the mod name
            # @param image_ids [Array<String>] array of image IDs
            # @return [void]
            def call(mod_name:, image_ids:, **)
              # Edit images via Portal
              portal.edit_mod_images(mod_name, image_ids)

              say "Image list updated successfully!", prefix: :success
              say "Total images: #{image_ids.size}"
            end
          end
        end
      end
    end
  end
end
